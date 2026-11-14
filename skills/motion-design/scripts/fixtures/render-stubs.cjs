// Preload external-operation doubles before the real CLI's ESM imports bind.
const { EventEmitter } = require('node:events');
const { Writable } = require('node:stream');
const { syncBuiltinESMExports } = require('node:module');
const scenario = process.env.RENDER_TEST_CASE;
const mark = message => console.log(`TEST: ${message}`);
const pending = () => new Promise(() => {});
let encoder;
const realSpawn = require('node:child_process').spawn;
require('node:child_process').spawn = (_command, _args, options) => {
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
  if (String(fn).includes('renderAudio')) return { wav: '', peak: 0, rms: [0] };
  return { DUR: 1, FPS: 2, W: 1920, H: 1080 };
};
page.$ = async () => ({ screenshot: async () => {
  if (scenario === 'screenshot') throw new Error('fixture screenshot');
  return scenario === 'child-early-exit' ? Buffer.alloc(1024 * 1024) : Buffer.from('fixture frame');
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
