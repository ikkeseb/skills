// render.mjs: step the reel frame by frame (exact on any machine, GPU or not), render its audio
// offline, mux both into an mp4 at a fixed loudness.
// usage: node render.mjs <out.mp4> [--query "music=b&s3=s3b"] [--blur 8] [--from <s>] [--to <s>] [--url http://127.0.0.1:8791/index.html]
// Needs ffmpeg on PATH and Playwright: `playwright` or `playwright-core` resolvable from here, or PW_MODULE=<path>.
import { spawn } from 'node:child_process';
import { writeFileSync } from 'node:fs';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
function loadPlaywright() {
  for (const m of [process.env.PW_MODULE, 'playwright', 'playwright-core'].filter(Boolean)) {
    try { return require(m); } catch { /* try the next */ }
  }
  throw new Error('Playwright not found: install playwright-core here or set PW_MODULE');
}
const { chromium } = loadPlaywright();

const args = process.argv.slice(2);
const opt = (name, def) => { const i = args.indexOf(`--${name}`); return i >= 0 ? args[i + 1] : def; };
const out = args.find(a => a.endsWith('.mp4')) || 'reel.mp4';
const blur = parseInt(opt('blur', '1'), 10);
const from = parseFloat(opt('from', '0'));
const url = `${opt('url', 'http://127.0.0.1:8791/index.html')}?t=0&${opt('query', '')}`;

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
const errors = [];
page.on('pageerror', e => errors.push(e.message));
page.on('console', m => m.type() === 'error' && errors.push(m.text()));
await page.goto(url);
await page.waitForSelector('body[data-ready="1"]');

const { DUR, FPS, W, H } = await page.evaluate(() => ({ DUR: REEL.DUR, FPS: REEL.FPS, W: REEL.W, H: REEL.H }));
if (W !== 1920 || H !== 1080) await page.setViewportSize({ width: W, height: H });
const audio = await page.evaluate(() => REEL.renderAudio());
const wavPath = out.replace(/\.mp4$/, '.wav');
writeFileSync(wavPath, Buffer.from(audio.wav, 'base64'));
console.log(`audio: peak ${audio.peak}, rms/bar ${audio.rms.join(' ')}`);

const to = Math.min(DUR, parseFloat(opt('to', String(DUR))));
const ff = spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(FPS), '-i', '-',
  '-ss', String(from), '-i', wavPath, '-c:v', 'libx264', '-preset', 'slow', '-crf', '18', '-pix_fmt', 'yuv420p',
  '-af', 'loudnorm=I=-14:TP=-1:LRA=11', '-ar', '48000', '-c:a', 'aac', '-b:a', '192k',
  '-shortest', '-movflags', '+faststart', out], { stdio: ['pipe', 'inherit', 'inherit'] });

const canvas = await page.$('canvas');
const f0 = Math.round(from * FPS), n = Math.floor(to * FPS) - f0;
for (let i = 0; i < n; i++) {
  await page.evaluate(([t, b]) => REEL.renderAt(t, { blur: b }), [(f0 + i) / FPS, blur]);
  const png = await canvas.screenshot({ type: 'png' });
  if (!ff.stdin.write(png)) await new Promise(r => ff.stdin.once('drain', r));
  if (i % (FPS * 3) === 0) console.log(`frame ${i}/${n}`);
}
ff.stdin.end();
await new Promise(r => ff.on('close', r));
await browser.close();
console.log(errors.length ? `page errors:\n${[...new Set(errors)].join('\n')}` : 'no page errors');
console.log(`wrote ${out}`);
