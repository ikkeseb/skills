// Preload external-operation doubles before the real CLI's ESM imports bind.
const { EventEmitter } = require('node:events');
const { readFileSync } = require('node:fs');
const { Writable } = require('node:stream');
const { syncBuiltinESMExports } = require('node:module');
const scenario = process.env.RENDER_TEST_CASE;
const mark = message => console.log(`TEST: ${message}`);
const pending = () => new Promise(() => {});
// The 16-bit stereo 48 kHz WAV REEL.renderAudio() returns, as a sine at `amplitude` (0 is digital silence).
const wav = (seconds, amplitude) => {
  const n = Math.round(seconds * 48000), out = Buffer.alloc(44 + n * 4);
  out.write('RIFF', 0); out.writeUInt32LE(36 + n * 4, 4); out.write('WAVEfmt ', 8);
  out.writeUInt32LE(16, 16); out.writeUInt16LE(1, 20); out.writeUInt16LE(2, 22); out.writeUInt32LE(48000, 24);
  out.writeUInt32LE(48000 * 4, 28); out.writeUInt16LE(4, 32); out.writeUInt16LE(16, 34);
  out.write('data', 36); out.writeUInt32LE(n * 4, 40);
  for (let i = 0; i < n; i++) {
    const v = Math.round(amplitude * 32767 * Math.sin(2 * Math.PI * 440 * i / 48000));
    out.writeInt16LE(v, 44 + i * 4); out.writeInt16LE(v, 46 + i * 4);
  }
  return out.toString('base64');
};
const frame = Buffer.from('iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAAACXBIWXMAAAABAAAAAQBPJcTWAAAAEElEQVR4nGNgGAWjYBTAAAADEAABPywr7AAAAABJRU5ErkJggg==', 'base64');
let encoder;
const realSpawn = require('node:child_process').spawn;
require('node:child_process').spawn = (command, args, options) => {
  mark(`encoder args ${args.join(' ')}`);
  const audio = readFileSync(args.find(a => a.endsWith('.wav')));
  mark(`audio input ${(audio.length - 44) / 4} samples, header ${audio.readUInt32LE(40) / 4}`);
  if (scenario.startsWith('ffmpeg-')) {
    // The real encoder on a real WAV and real PNG frames: the arguments must work, not only parse.
    const child = realSpawn(command, args, options);
    child.on('close', (code, signal) => mark(`encoder closed ${code} ${signal}`));
    return child;
  }
  if (scenario.startsWith('child-')) {
    // Real ChildProcess/pipe lifecycle, without requiring ffmpeg or a shell.
    const source = scenario === 'child-signal' ? "process.kill(process.pid, 'SIGTERM')"
      : scenario === 'child-early-exit' ? 'process.exit(23)'
      : `process.stdin.resume(); process.stdin.on('end', () => process.exit(${scenario === 'child-exit' ? 23 : 0}));`;
    const child = realSpawn(scenario === 'child-missing' ? process.execPath + '.missing' : process.execPath,
      ['-e', source], options);
    child.on('close', (code, signal) => mark(`encoder closed ${code} ${signal}`));
    return child;
  }
  encoder = new EventEmitter();
  let closed = false;
  const close = (code, signal = null) => {
    if (closed) return;
    closed = true;
    mark(`encoder closed ${code} ${signal}`);
    encoder.emit('close', code, signal);
  };
  encoder.kill = signal => { mark('encoder killed'); setImmediate(() => close(null, signal)); return true; };
  encoder.stdin = new Writable({
    highWaterMark: 1,
    write(chunk, encoding, callback) {
      if (scenario === 'pipe-error') return setImmediate(() => callback(new Error('fixture EPIPE')));
      if (scenario === 'pipe-close') return setImmediate(() => this.destroy());
      if (scenario === 'early-exit') return setImmediate(() => close(23));
      if (scenario === 'early-zero') return setImmediate(() => close(0));
      setImmediate(callback);
    },
    final(callback) {
      callback();
      setImmediate(() => close(scenario === 'exit' ? 23 : scenario === 'signal' ? null : 0,
        scenario === 'signal' ? 'SIGTERM' : null));
    },
  });
  // A real process keeps the CLI alive until exit; catch orphaned encoders.
  const keepAlive = setInterval(() => {}, 1000);
  encoder.on('close', () => clearInterval(keepAlive));
  if (scenario === 'spawn-error') setImmediate(() => {
    encoder.emit('error', new Error('fixture ENOENT'));
    close(-2);
  });
  return encoder;
};
syncBuiltinESMExports();
const page = new EventEmitter();
page.goto = async () => {
  if (scenario === 'goto') throw new Error('fixture navigation');
  if (scenario === 'page-error') page.emit('pageerror', new Error('fixture page error'));
  if (scenario === 'console-error') page.emit('console', { type: () => 'error', text: () => 'fixture console error' });
};
page.waitForSelector = async () => {
  if (scenario === 'page-error-wait') {
    setImmediate(() => page.emit('pageerror', new Error('fixture waiting page error')));
    return pending();
  }
};
page.setViewportSize = async () => {};
page.evaluate = async (fn, args) => {
  if (args) {
    if (scenario === 'render') throw new Error('fixture frame render');
    if (scenario === 'page-error-frame') page.emit('pageerror', new Error('fixture frame page error'));
    return;
  }
  if (String(fn).includes('renderAudio')) {
    if (scenario.includes('silent')) return { wav: wav(2.2, 0), peak: 0, rms: [0] };
    // Silence but for sample frame 48000 (1 s), which a --from 1.000001 render still encodes.
    if (scenario.includes('edge')) {
      const data = Buffer.from(wav(2.2, 0), 'base64');
      data.writeInt16LE(1000, 44 + 48000 * 4); data.writeInt16LE(1000, 46 + 48000 * 4);
      return { wav: data.toString('base64'), peak: 0.03, rms: [0] };
    }
    // A WAV ending at 1.2 s, short of the 2 s reel.
    if (scenario === 'short') return { wav: wav(1.2, 0.3), peak: 0.3, rms: [0.212] };
    // A loud open, then digital silence from 1 s: a --from 1 render reads only the silent part.
    if (scenario.includes('silence')) {
      const loud = Buffer.from(wav(1, 0.3), 'base64');
      const quiet = Buffer.from(wav(scenario === 'short-silence' ? 0.2 : 1.2, 0), 'base64');
      const data = Buffer.concat([loud, quiet.subarray(44)]);
      data.writeUInt32LE(36 + data.length - 44, 4); data.writeUInt32LE(data.length - 44, 40);
      return { wav: data.toString('base64'), peak: 0.3, rms: [0.212] };
    }
    return { wav: wav(2.2, 0.3), peak: 0.3, rms: [0.212] };
  }
  return { DUR: /silence|edge|short/.test(scenario) ? 2 : 1, FPS: 2, W: 1920, H: 1080 };
};
page.$ = async () => ({ screenshot: async () => {
  if (scenario === 'screenshot') throw new Error('fixture screenshot');
  return scenario === 'child-early-exit' ? Buffer.alloc(1024 * 1024) : frame;
} });
exports.chromium = { launch: async () => ({
  newPage: async () => {
    if (scenario === 'new-page') throw new Error('fixture new page');
    return page;
  },
  close: async () => {
    mark('browser closed');
    if (scenario === 'browser-close') throw new Error('fixture browser close');
  },
}) };
