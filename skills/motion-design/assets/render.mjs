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
let ff, encoderDone, encoderClosed = false;
let failure;
let rejectFailure;
const failed = new Promise((_, reject) => { rejectFailure = reject; });
// Events may arrive between awaited operations; keep the first failure without
// an unhandled rejection, then race it against every operation that can wait.
failed.catch(() => {});
const fail = error => {
  if (!failure) {
    failure = error;
    rejectFailure(error);
  }
};
const checked = async operation => {
  const result = await Promise.race([operation, failed]);
  if (failure) throw failure;
  return result;
};

try {
  const page = await checked(browser.newPage({ viewport: { width: 1920, height: 1080 } }));
  page.on('pageerror', e => fail(new Error(`page error: ${e.message}`)));
  page.on('console', m => {
    if (m.type() === 'error') fail(new Error(`page console error: ${m.text()}`));
  });
  await checked(page.goto(url));
  await checked(page.waitForSelector('body[data-ready="1"]'));

  const { DUR, FPS, W, H } = await checked(page.evaluate(() => ({ DUR: REEL.DUR, FPS: REEL.FPS, W: REEL.W, H: REEL.H })));
  if (W !== 1920 || H !== 1080) await checked(page.setViewportSize({ width: W, height: H }));
  const audio = await checked(page.evaluate(() => REEL.renderAudio()));
  const wavPath = out.replace(/\.mp4$/, '.wav');
  writeFileSync(wavPath, Buffer.from(audio.wav, 'base64'));
  console.log(`audio: peak ${audio.peak}, rms/bar ${audio.rms.join(' ')}`);

  const to = Math.min(DUR, parseFloat(opt('to', String(DUR))));
  ff = spawn('ffmpeg', ['-y', '-loglevel', 'error', '-f', 'image2pipe', '-framerate', String(FPS), '-i', '-',
    '-ss', String(from), '-i', wavPath, '-c:v', 'libx264', '-preset', 'slow', '-crf', '18', '-pix_fmt', 'yuv420p',
    '-af', 'loudnorm=I=-14:TP=-1:LRA=11', '-ar', '48000', '-c:a', 'aac', '-b:a', '192k',
    '-shortest', '-movflags', '+faststart', out], { stdio: ['pipe', 'inherit', 'inherit'] });

  // Register before rendering frames: an encoder can fail before the first write.
  ff.on('error', e => fail(new Error(`ffmpeg: ${e.message}`)));
  ff.stdin.on('error', e => fail(new Error(`ffmpeg stdin: ${e.message}`)));
  ff.stdin.on('close', () => {
    if (!ff.stdin.writableFinished) fail(new Error('ffmpeg stdin closed before all input was written'));
  });
  encoderDone = new Promise(resolve => ff.once('close', (code, signal) => {
    encoderClosed = true;
    if (code !== 0) fail(new Error(`ffmpeg failed: ${signal ? `signal ${signal}` : `exit ${code}`}`));
    else if (!ff.stdin.writableFinished) fail(new Error('ffmpeg exited before all input was written'));
    resolve();
  }));

  const canvas = await checked(page.$('canvas'));
  const f0 = Math.round(from * FPS), n = Math.floor(to * FPS) - f0;
  for (let i = 0; i < n; i++) {
    await checked(page.evaluate(([t, b]) => REEL.renderAt(t, { blur: b }), [(f0 + i) / FPS, blur]));
    const png = await checked(canvas.screenshot({ type: 'png' }));
    // Waiting for each write callback bounds buffering and also handles errors
    // when the stream never emits drain.
    await checked(new Promise((resolve, reject) => {
      ff.stdin.write(png, error => error ? reject(error) : resolve());
    }));
    if (i % (FPS * 3) === 0) console.log(`frame ${i}/${n}`);
  }
  ff.stdin.end();
  await checked(encoderDone);
} finally {
  // An interrupted render must not leave an encoder waiting for more frames.
  if (ff && !encoderClosed) {
    ff.stdin.destroy();
    ff.kill('SIGKILL');
  }
  try {
    await browser.close();
  } finally {
    if (encoderDone) await encoderDone;
  }
}
if (failure) throw failure;
console.log('no page errors');
console.log(`wrote ${out}`);
