// reel.js: the seat's file. The product's look, the timeline with its exact copy, the score,
// and the product's signature component(s). Replace every value below; keep the shape.
window.REEL_CONFIG = (function () {
  // The product's own tokens, read from its stylesheet or design system, not invented.
  const C = {
    bg: '#0b0c0f', surface: '#14161b', edge: 'rgba(255,255,255,0.08)',
    text: '#eef1f8', dim: '#b9bcc6', faint: '#7d818d',
    accent: '#36e39a', accent2: '#ffae2a', alert: '#ff3b52',
  };

  // Scenes change on bar lines. Copy lives in the brief's scene table; scenes render it verbatim.
  const SCENES = [
    { id: 's1', from: 0, bars: 2, name: 'Open' },
    { id: 's2', from: 2, bars: 2, name: 'The idea' },
    { id: 's3', from: 4, bars: 4, name: 'Peak' },
    { id: 's4', from: 8, bars: 2, name: 'End card' },
  ];

  // Optional wipes in place of cuts: the next scene sweeps in behind a moving edge over [from, at) and owns the
  // frame on the hit (engine.js documents the fields). Example: { at: 16, from: 15, dir: 'ltr', edge: 'line' }.
  const SEAMS = [];

  // The score: every sound event in global beats. Music plays it; scenes sync to it via
  // k.env(inst) and k.since(inst). Build layers so the picture and the arrangement grow together.
  const SCORE = [];
  const add = (i, b, o) => SCORE.push(Object.assign({ i, b, v: 1, d: 0.25 }, o));
  const bars = (a, z, fn) => { for (let bar = a; bar < z; bar++) fn(bar * 4, bar % 4); };
  const CHORDS = [[57, 60, 64], [53, 57, 60], [55, 60, 64], [55, 59, 62]]; // Am F C G
  const ROOTS = [33, 29, 36, 31];
  bars(0, 2, b0 => { for (let k = 0; k < 4; k++) add('hat', b0 + k + 0.5, { v: 0.6 }); });
  bars(2, 8, b0 => { for (let k = 0; k < 4; k++) add('kick', b0 + k); });
  bars(2, 8, (b0, c) => { for (let k = 0; k < 4; k++) add('bass', b0 + k + 0.5, { n: ROOTS[c], d: 0.4 }); });
  bars(4, 8, (b0, c) => add('pad', b0, { n: CHORDS[c], d: 4 }));
  add('crash', 16);
  add('kick', 32); add('pad', 32, { n: CHORDS[0], d: 8 });

  // The product's signature component, drawn once here so every scene shows the same thing.
  function card(k, ctx, x, y, w, h, o = {}) {
    k.rrect(ctx, x, y, w, h, o.r || 20); ctx.fillStyle = C.surface; ctx.fill();
    ctx.strokeStyle = o.border || C.edge; ctx.lineWidth = 1.5; ctx.stroke();
  }
  function bg(k, ctx) {
    ctx.fillStyle = C.bg; ctx.fillRect(0, 0, k.W, k.H);
  }

  return {
    W: 1920, H: 1080, FPS: 60, BPM: 140, BARS: 10, C, SCENES, SEAMS, SCORE,
    // the film finish the engine adds after the blur; a direction's scene file may override it
    // with REEL.LOOK; 0 turns either off
    LOOK: { grain: 0.035, vignette: 0.35 },
    FONT: { sans: "'Inter'", mono: "'JetBrains Mono'" },
    FONT_LOADS: ["600 40px 'Inter'", "700 40px 'Inter'", "500 40px 'JetBrains Mono'"],
    helpers: { card, bg },
  };
})();
