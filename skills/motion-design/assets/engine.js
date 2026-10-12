// engine.js: the reel's fixed infrastructure. One clock, frame-exact rendering, motion blur,
// offline audio. reel.js (loaded first) supplies the look, the timeline and the score.
// Scene and music authors never edit this file.
(function () {
  const cfg = window.REEL_CONFIG;
  const W = cfg.W || 1920, H = cfg.H || 1080, FPS = cfg.FPS || 60, BPM = cfg.BPM;
  const BEAT = 60 / BPM, BAR = 4 * BEAT, BARS = cfg.BARS, DUR = BARS * BAR;
  const C = cfg.C, SCENES = cfg.SCENES, FONT = cfg.FONT || { sans: 'sans-serif', mono: 'monospace' };

  const ev = cfg.SCORE.slice().sort((a, b) => a.b - b.b);
  const byInst = {};
  for (const e of ev) (byInst[e.i] = byInst[e.i] || []).push(e);

  // ---------- helpers given to every scene as `k` ----------
  const clamp = (x, a = 0, b = 1) => Math.min(b, Math.max(a, x));
  const lerp = (a, b, t) => a + (b - a) * t;
  const ease = {
    outCubic: t => 1 - Math.pow(1 - clamp(t), 3),
    inCubic: t => Math.pow(clamp(t), 3),
    inOutCubic: t => { t = clamp(t); return t < 0.5 ? 4 * t * t * t : 1 - Math.pow(-2 * t + 2, 3) / 2; },
    outExpo: t => (t = clamp(t)) === 1 ? 1 : 1 - Math.pow(2, -10 * t),
    outBack: t => { t = clamp(t); const c = 1.70158; return 1 + (c + 1) * Math.pow(t - 1, 3) + c * Math.pow(t - 1, 2); },
  };
  // 0..1 as x runs from a to b, e.g. k.range(k.lb, 0, 1) over the scene's first beat
  const range = (x, a, b) => clamp((x - a) / (b - a));

  function last(inst, beat) {
    const a = byInst[inst]; if (!a) return null;
    let lo = 0, hi = a.length - 1, r = null;
    while (lo <= hi) { const m = (lo + hi) >> 1; if (a[m].b <= beat + 1e-6) { r = a[m]; lo = m + 1; } else hi = m - 1; }
    return r;
  }

  function rng(seed) {
    let s = seed >>> 0 || 1;
    return () => { s ^= s << 13; s ^= s >>> 17; s ^= s << 5; return ((s >>> 0) % 100000) / 100000; };
  }

  function rrect(ctx, x, y, w, h, r) { ctx.beginPath(); ctx.roundRect(x, y, w, h, r); }

  function font(o) { return `${o.weight || 600} ${o.size || 48}px ${o.mono ? FONT.mono : FONT.sans}`; }
  function text(ctx, str, x, y, o = {}) {
    const size = o.size || 48;
    ctx.save();
    ctx.font = font(o);
    ctx.letterSpacing = `${(o.tracking || 0) * size}px`;
    ctx.fillStyle = o.color || C.text;
    ctx.textAlign = o.align || 'left';
    ctx.textBaseline = o.baseline || 'alphabetic';
    if (o.alpha != null) ctx.globalAlpha *= o.alpha;
    if (o.glow) { ctx.shadowColor = o.glow; ctx.shadowBlur = o.glowBlur || size * 0.4; }
    ctx.fillText(str, x, y);
    ctx.restore();
  }
  function measure(ctx, str, o = {}) {
    ctx.save(); ctx.font = font(o); ctx.letterSpacing = `${(o.tracking || 0) * (o.size || 48)}px`;
    const w = ctx.measureText(str).width; ctx.restore(); return w;
  }

  const registry = {};
  const R = window.REEL = {
    W, H, FPS, BPM, BEAT, BAR, BARS, DUR, C, SCENES, SCORE: ev,
    scene(id, fn) { registry[id] = fn; },
    music: null, // set by music/<x>.js: function (ac, dest, when) scheduling every SCORE event
  };

  const k = {
    W, H, C, BEAT, BAR, BPM, clamp, lerp, ease, range, rng, rrect, text, measure,
    // seconds since the last hit of an instrument (Infinity before the first)
    since(inst) { const e = last(inst, k.beat); return e ? (k.beat - e.b) * BEAT : Infinity; },
    // 1 on a hit, decaying over `decay` beats: drive scale, glow and flashes from the music
    env(inst, decay = 0.5) { const e = last(inst, k.beat); return e ? e.v * Math.exp(-(k.beat - e.b) / decay) : 0; },
    events(inst) { return byInst[inst] || []; },
  };
  // the product's own components (signature UI, background) from reel.js, bound to k
  for (const [name, fn] of Object.entries(cfg.helpers || {})) k[name] = (...a) => fn(k, ...a);
  if (!k.bg) k.bg = ctx => { ctx.fillStyle = C.bg; ctx.fillRect(0, 0, W, H); };

  function sceneAt(t) {
    const bar = t / BAR;
    for (let i = SCENES.length - 1; i >= 0; i--) if (bar >= SCENES[i].from - 1e-9) return SCENES[i];
    return SCENES[0];
  }

  let ctx, acc, accCtx, sub, subCtx;
  function draw(target, t) {
    t = clamp(t, 0, DUR - 1e-6);
    const sc = sceneAt(t);
    k.t = t; k.beat = t / BEAT; k.bar = t / BAR;
    k.lt = t - sc.from * BAR; k.lb = k.lt / BEAT; k.dur = sc.bars * BAR; k.p = k.lt / k.dur; k.scene = sc;
    target.save(); target.setTransform(1, 0, 0, 1, 0, 0); target.globalAlpha = 1; target.shadowBlur = 0;
    const fn = registry[sc.id];
    if (fn) { try { fn(target, k); } catch (e) { k.bg(target); text(target, sc.id + ' threw: ' + e.message, 80, H / 2, { size: 36, color: '#ff4d4d' }); console.error(e); } }
    else { k.bg(target); text(target, `${sc.id} · ${sc.name} (missing)`, W / 2, H / 2, { size: 64, align: 'center', color: '#888' }); }
    target.restore();
  }

  // Motion blur: average `blur` sub-frames across `shutter` of the frame interval, never across a cut
  // (a sub-frame from the next scene would ghost into this one).
  function renderAt(t, o = {}) {
    const n = o.blur || 1;
    if (n <= 1) { draw(ctx, t); post(t); return; }
    const span = (o.shutter != null ? o.shutter : 0.5) / FPS;
    const sc = sceneAt(t), end = (sc.from + sc.bars) * BAR - 1e-4;
    accCtx.globalCompositeOperation = 'copy';
    for (let j = 0; j < n; j++) {
      const ts = Math.min(end, t + span * (j / n));
      draw(subCtx, ts);
      accCtx.globalAlpha = 1 / (j + 1);
      accCtx.drawImage(sub, 0, 0);
      accCtx.globalCompositeOperation = 'source-over';
    }
    ctx.save(); ctx.setTransform(1, 0, 0, 1, 0, 0); ctx.globalAlpha = 1; ctx.globalCompositeOperation = 'copy';
    ctx.drawImage(acc, 0, 0); ctx.restore();
    post(t);
  }
  // Film finish, once per output frame after the blur (grain drawn per sub-frame would average away):
  // a grain tile that changes every frame and a soft vignette. reel.js sets the defaults (LOOK); a
  // direction may override them with REEL.LOOK.
  const LOOK = Object.assign({ grain: 0.035, vignette: 0.35 }, cfg.LOOK || {});
  let grainTiles = null;
  function post(t) {
    const L = Object.assign({}, LOOK, R.LOOK || {}); // a direction's scene file may set REEL.LOOK
    if (!grainTiles) {
      const r = rng(7); grainTiles = [];
      for (let g = 0; g < 4; g++) {
        const c = new OffscreenCanvas(256, 256), x = c.getContext('2d'), im = x.createImageData(256, 256);
        for (let i = 0; i < im.data.length; i += 4) { const v = r() < 0.5 ? 0 : 255; im.data[i] = im.data[i + 1] = im.data[i + 2] = v; im.data[i + 3] = Math.floor(r() * 255); }
        x.putImageData(im, 0, 0); grainTiles.push(c);
      }
    }
    const f = Math.floor(t * FPS + 1e-6);
    ctx.save(); ctx.setTransform(1, 0, 0, 1, 0, 0);
    if (L.vignette > 0) {
      const g = ctx.createRadialGradient(W / 2, H / 2, H * 0.45, W / 2, H / 2, W * 0.62);
      g.addColorStop(0, 'rgba(0,0,0,0)'); g.addColorStop(1, `rgba(0,0,0,${L.vignette})`);
      ctx.fillStyle = g; ctx.fillRect(0, 0, W, H);
    }
    if (L.grain > 0) {
      ctx.globalAlpha = L.grain;
      ctx.fillStyle = ctx.createPattern(grainTiles[f % 4], 'repeat');
      const ox = (f * 97) % 256, oy = (f * 61) % 256;
      ctx.translate(-ox, -oy); ctx.fillRect(0, 0, W + 256, H + 256);
    }
    ctx.restore();
  }
  R.renderAt = window.renderAt = renderAt;

  // ---------- audio: the offline render that goes into the video ----------
  R.renderAudio = async function () {
    const sr = 48000, ac = new OfflineAudioContext(2, Math.ceil((DUR + 0.2) * sr), sr);
    R.music(ac, ac.destination, 0);
    const buf = await ac.startRendering();
    const n = buf.length, ch = [buf.getChannelData(0), buf.getChannelData(1)];
    const out = new DataView(new ArrayBuffer(44 + n * 4));
    const w = (o, s) => [...s].forEach((c, i) => out.setUint8(o + i, c.charCodeAt(0)));
    w(0, 'RIFF'); out.setUint32(4, 36 + n * 4, true); w(8, 'WAVE'); w(12, 'fmt ');
    out.setUint32(16, 16, true); out.setUint16(20, 1, true); out.setUint16(22, 2, true);
    out.setUint32(24, sr, true); out.setUint32(28, sr * 4, true); out.setUint16(32, 4, true); out.setUint16(34, 16, true);
    w(36, 'data'); out.setUint32(40, n * 4, true);
    let peak = 0;
    for (let i = 0; i < n; i++) for (let c = 0; c < 2; c++) {
      const v = ch[c][i]; peak = Math.max(peak, Math.abs(v));
      out.setInt16(44 + i * 4 + c * 2, Math.max(-1, Math.min(1, v)) * 32767, true);
    }
    // per-bar RMS: the arrangement made visible to a reader without ears
    const rms = [];
    for (let b = 0; b < BARS; b++) {
      let s = 0; const a = Math.floor(b * BAR * sr), z = Math.floor((b + 1) * BAR * sr);
      for (let i = a; i < z; i++) s += ch[0][i] * ch[0][i];
      rms.push(+Math.sqrt(s / (z - a)).toFixed(3));
    }
    let bin = ''; const bytes = new Uint8Array(out.buffer);
    for (let i = 0; i < bytes.length; i += 0x8000) bin += String.fromCharCode.apply(null, bytes.subarray(i, i + 0x8000));
    return { wav: btoa(bin), peak: +peak.toFixed(3), rms };
  };

  // ---------- boot: ?t=<s> renders one still, ?scene=<id> loops a scene, otherwise click to play ----------
  R.boot = async function (canvas) {
    canvas.width = W; canvas.height = H; ctx = canvas.getContext('2d');
    acc = new OffscreenCanvas(W, H); accCtx = acc.getContext('2d');
    sub = new OffscreenCanvas(W, H); subCtx = sub.getContext('2d');
    // a missing font is reported, not fatal: the render lists it among the page errors
    await Promise.all((cfg.FONT_LOADS || []).map(f => document.fonts.load(f).catch(() => console.error('font failed to load: ' + f))));
    const q = new URLSearchParams(location.search);
    const hint = document.getElementById('hint');
    if (q.has('t')) { if (hint) hint.style.display = 'none'; renderAt(parseFloat(q.get('t'))); document.body.dataset.ready = '1'; return; }
    const only = q.get('scene') && SCENES.find(s => s.id === q.get('scene'));
    const loopFrom = only ? only.from * BAR : 0, loopLen = only ? only.bars * BAR : DUR;
    let ac = null, t0 = 0;
    const start = performance.now();
    function frame() {
      const t = ac ? ac.currentTime - t0 : (performance.now() - start) / 1000;
      renderAt(loopFrom + (t % loopLen));
      requestAnimationFrame(frame);
    }
    document.body.dataset.ready = '1';
    if (only) { if (hint) hint.style.display = 'none'; frame(); return; }
    renderAt(0);
    const go = () => {
      if (ac) return;
      ac = new AudioContext(); t0 = ac.currentTime + 0.1;
      if (R.music) R.music(ac, ac.destination, t0);
      if (hint) hint.style.display = 'none';
      frame();
    };
    window.addEventListener('click', go); window.addEventListener('keydown', go);
  };
})();
