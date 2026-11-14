#!/usr/bin/env node
// Exercise the unmodified CLI in isolation, with only external operations stubbed.
import assert from 'node:assert/strict';
import { copyFileSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, join } from 'node:path';
import { spawnSync } from 'node:child_process';

const root = mkdtempSync(join(tmpdir(), 'drawio-render-test-'));
try {
  const renderer = join(root, 'render-drawio.mjs');
  copyFileSync(new URL('./render-drawio.mjs', import.meta.url), renderer);
  const moduleDir = join(root, 'node_modules', 'playwright');
  mkdirSync(moduleDir, { recursive: true });
  writeFileSync(join(moduleDir, 'index.js'), `
    const { appendFileSync, writeFileSync } = require('node:fs');
    module.exports.chromium = { async launch() { return {
      async newContext() { return { async newPage() {
        let index;
        return {
          on() {},
          async setContent(html) { index = JSON.parse(html.match(/data-mxgraph='([^']*)'/)[1].replace(/&#39;/g, "'").replace(/&amp;/g, '&')).page; },
          async waitForSelector() {}, async waitForTimeout() {},
          locator() { return { first() { return { async screenshot({ path }) {
            appendFileSync(process.env.RENDER_LOG, JSON.stringify({ index, path }) + '\\n');
            writeFileSync(path, String(index));
          } }; } }; },
          async close() {},
        };
      } }; },
      async close() {},
    }; } };
  `);
  const preload = join(root, 'preload.mjs');
  writeFileSync(preload, `
    import cp from 'node:child_process';
    import { syncBuiltinESMExports } from 'node:module';
    // Never invoke package managers or consult installed browser providers.
    cp.execSync = () => ${JSON.stringify(join(root, 'node_modules'))};
    syncBuiltinESMExports();
  `);

  let runNumber = 0;
  function render(names, filter) {
    const runDir = join(root, String(runNumber++));
    mkdirSync(runDir);
    const file = join(runDir, 'input.drawio');
    const out = join(runDir, 'out');
    const log = join(runDir, 'screenshots.jsonl');
    writeFileSync(file, `<mxfile>${names.map(name => `<diagram name="${name}"><mxGraphModel/></diagram>`).join('')}</mxfile>`);
    const args = ['--import', preload, renderer, file, '--out', out];
    if (filter) args.push('--pages', filter);
    const result = spawnSync(process.execPath, args, {
      encoding: 'utf8', timeout: 10000,
      env: { ...process.env, NODE_OPTIONS: '', NODE_PATH: '', PLAYWRIGHT_BROWSERS_PATH: '0', RENDER_LOG: log },
    });
    assert.ifError(result.error);
    assert.equal(result.status, 0, result.stderr);
    const captures = readFileSync(log, 'utf8').trim().split('\n').map(line => JSON.parse(line));
    assert.equal(readdirSync(out).length, captures.length, `Overwritten screenshots: ${JSON.stringify(captures)}`);
    assert.equal(new Set(captures.map(c => basename(c.path).toLowerCase())).size, captures.length, 'Names must also be distinct on case-insensitive filesystems');
    for (const capture of captures) assert.equal(readFileSync(capture.path, 'utf8'), String(capture.index));
    return captures.map(c => ({ index: c.index, name: basename(c.path) }));
  }

  const collision = render(['A/B', 'A?B']);
  assert.deepEqual(collision, [{ index: 0, name: 'A_B.png' }, { index: 1, name: 'A_B-2.png' }]);
  assert.deepEqual(render(['Architecture', 'Flow-2.v1', 'A B']), [
    { index: 0, name: 'Architecture.png' }, { index: 1, name: 'Flow-2.v1.png' }, { index: 2, name: 'A_B.png' },
  ]);
  assert.deepEqual(render(['Same', 'Same', 'Same']), [
    { index: 0, name: 'Same.png' }, { index: 1, name: 'Same-2.png' }, { index: 2, name: 'Same-3.png' },
  ]);
  const tricky = ['A/B', 'A?B', 'A_B-2', 'A_B-3', 'A_B-2', 'a_b', '日本語', '中文', 'é', ''];
  const all = render(tricky);
  assert.equal(all[2].name, 'A_B-2.png', 'Generated suffixes must preserve original names');
  assert.equal(all[3].name, 'A_B-3.png');
  assert.deepEqual(render(tricky), all, 'Allocation must be deterministic');
  for (const filter of ['A?B', 'a_b', '日本語', '中文', 'é', 'A_B-2']) {
    assert.deepEqual(render(tricky, filter), all.filter(c => tricky[c.index].includes(filter)), 'Filtering must not change filenames');
  }
  console.log('drawio renderer: offline filename regressions passed');
} finally {
  rmSync(root, { recursive: true, force: true });
}
