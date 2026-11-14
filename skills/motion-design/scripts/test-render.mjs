#!/usr/bin/env node
import assert from 'node:assert/strict';
import { spawnSync } from 'node:child_process';
import { existsSync, mkdtempSync, rmSync } from 'node:fs';
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
  // Loudness normalization of digital silence yields NaN that the AAC encoder rejects.
  ['silent', null], ['from-silence', null, ['--from', '1']],
  // The silence check reads the samples the encoder gets: at a fractional trim edge, and past a short WAV's end.
  ['edge', null, ['--from', '1.000001']], ['short', null, ['--from', '1']], ['short-silence', null, ['--from', '1']],
  // The real encoder, where one is installed.
  ['ffmpeg-good', null], ['ffmpeg-silent', null], ['ffmpeg-from-silence', null, ['--from', '1']],
  ['ffmpeg-edge', null, ['--from', '1.000001']],
];
const has = tool => spawnSync(tool, ['-version'], { stdio: 'ignore' }).status === 0;
const hasFfmpeg = has('ffmpeg'), hasFfprobe = has('ffprobe');
const loudnorm = /encoder args .*-af loudnorm=I=-14:TP=-1:LRA=11 /;
const skipped = /loudness normalization skipped/;
let failures = 0;
try {
  for (const [scenario, diagnostic, extra = []] of cases) {
    if (scenario.startsWith('ffmpeg-') && !hasFfmpeg) {
      console.log(`SKIP: motion render ${scenario} (ffmpeg not on PATH)`);
      continue;
    }
    rmSync(join(workspace, 'probe.mp4'), { force: true });
    const result = spawnSync(process.execPath, ['--require', stub, cli, 'probe.mp4', ...extra], {
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
        // One second of frames at 48 kHz, or the 0.2 s a short WAV has left; the header agrees.
        const samples = scenario.startsWith('short') ? 9600 : 48000;
        assert.match(result.stdout, new RegExp(`audio input ${samples} samples, header ${samples}\\b`), `${scenario}: encoder audio is the cut span`);
        if (/silen/.test(scenario)) {
          assert.doesNotMatch(result.stdout, loudnorm, `${scenario}: a silent track skips loudnorm`);
          assert.match(result.stdout, skipped);
        } else if (!scenario.startsWith('child-')) {
          assert.match(result.stdout, loudnorm, `${scenario}: an audible track keeps loudnorm`);
          assert.doesNotMatch(result.stdout, skipped);
        }
        if (scenario.startsWith('ffmpeg-')) {
          assert.ok(existsSync(join(workspace, 'probe.mp4')), `${scenario}: mp4 written`);
          if (hasFfprobe) {
            const streams = spawnSync('ffprobe', ['-v', 'error', '-show_entries', 'stream=codec_type', '-of', 'csv=p=0',
              join(workspace, 'probe.mp4')], { encoding: 'utf8' }).stdout.split(/\s+/).filter(Boolean).sort();
            assert.deepEqual(streams, ['audio', 'video'], `${scenario}: one video and one audio stream`);
          }
        }
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
