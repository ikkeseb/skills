#!/usr/bin/env node
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

const cli = fileURLToPath(new URL('../assets/render.mjs', import.meta.url));
const stub = fileURLToPath(new URL('./fixtures/render-stubs.cjs', import.meta.url));
const workspace = mkdtempSync(join(tmpdir(), 'motion-render-test-'));
const cases = [
  ['good', null], ['exit', /23/], ['signal', /SIGTERM/],
  ['spawn-error', /ENOENT/], ['pipe-error', /EPIPE/], ['pipe-close', /pipe|stdin/i],
  ['early-exit', /23/], ['early-zero', /early|before|input/i],
  ['page-error', /fixture page error/], ['console-error', /fixture console error/],
  ['page-error-wait', /fixture waiting page error/], ['page-error-frame', /fixture frame page error/],
  ['new-page', /fixture new page/], ['goto', /fixture navigation/],
  ['render', /fixture frame render/], ['screenshot', /fixture screenshot/],
  ['browser-close', /fixture browser close/],
  ['child-good', null], ['child-exit', /23/], ['child-signal', /ffmpeg/],
  ['child-early-exit', /ffmpeg|EPIPE/], ['child-missing', /ENOENT/],
];
let failures = 0;
try {
  for (const [scenario, diagnostic] of cases) {
    const result = spawnSync(process.execPath, ['--require', stub, cli, 'probe.mp4'], {
      cwd: workspace, encoding: 'utf8', timeout: 10000,
      env: { ...process.env, NODE_OPTIONS: '', NODE_PATH: '', PW_MODULE: stub, RENDER_TEST_CASE: scenario },
    });
    try {
      assert.equal(result.error, undefined, `${scenario}: CLI must finish without hanging`);
      if (diagnostic) {
        assert.notEqual(result.status, 0, `${scenario}: failure must exit nonzero; stdout: ${result.stdout}`);
        assert.doesNotMatch(result.stdout, /wrote probe\.mp4/);
        assert.match(result.stderr, diagnostic);
      } else {
        assert.equal(result.status, 0, result.stderr);
        assert.match(result.stdout, /wrote probe\.mp4/);
        assert.match(result.stdout, /frame 0\/2/);
        assert.match(result.stdout, /encoder closed 0 null/);
      }
      assert.equal(result.stdout.match(/TEST: browser closed/g)?.length, 1, `${scenario}: browser must close exactly once`);
      if (['render', 'screenshot', 'page-error-frame', 'pipe-error', 'pipe-close'].includes(scenario)) {
        assert.match(result.stdout, /TEST: encoder killed/, `${scenario}: stop the unfinished encoder`);
        assert.match(result.stdout, /TEST: encoder closed/, `${scenario}: wait for encoder shutdown`);
      }
      console.log(`PASS: motion render ${scenario}`);
    } catch (error) {
      failures++;
      console.error(`FAIL: ${error.message}`);
    }
  }
} finally {
  rmSync(workspace, { recursive: true, force: true });
}
if (failures) process.exitCode = 1;
