#!/usr/bin/env node
// Exercise the unmodified CLI in isolation, with only external operations stubbed.
import assert from 'node:assert/strict';
import { copyFileSync, existsSync, mkdirSync, mkdtempSync, readFileSync, readdirSync, rmSync, symlinkSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { basename, dirname, join } from 'node:path';
import { spawnSync } from 'node:child_process';

const root = mkdtempSync(join(tmpdir(), 'drawio-render-test-'));
try {
  const renderer = join(root, 'render-drawio.mjs');
  copyFileSync(new URL('./render-drawio.mjs', import.meta.url), renderer);
  const writeStub = (moduleDir) => {
  mkdirSync(moduleDir, { recursive: true });
  writeFileSync(join(moduleDir, 'index.js'), `
    const { appendFileSync, writeFileSync } = require('node:fs');
    if (process.env.LOAD_LOG) appendFileSync(process.env.LOAD_LOG, __filename);
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
  };
  writeStub(join(root, 'node_modules', 'playwright'));
  const preload = join(root, 'preload.mjs');
  writeFileSync(preload, `
    import cp from 'node:child_process';
    import { syncBuiltinESMExports } from 'node:module';
    // Never invoke package managers; an empty global root leaves only the local install.
    cp.execSync = () => ${JSON.stringify(join(root, 'no-global-root'))};
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

  // Global-install layouts, each in its own tree so no local node_modules is an ancestor.
  const link = (target, path) => {
    mkdirSync(dirname(path), { recursive: true });
    symlinkSync(target, path, process.platform === 'win32' ? 'junction' : 'dir');
  };
  const layouts = {
    'flat global': (g) => writeStub(join(g, 'playwright')),
    'nested in @playwright/cli': (g) => writeStub(join(g, '@playwright', 'cli', 'node_modules', 'playwright')),
    'pnpm v11, with @playwright/cli': (g, store) => {
      const pkgs = join(store, 'cli', 'node_modules');
      mkdirSync(join(pkgs, '@playwright', 'cli'), { recursive: true });
      writeFileSync(join(pkgs, '@playwright', 'cli', 'package.json'), '{"name":"@playwright/cli"}');
      writeStub(join(pkgs, 'playwright'));
      writeFileSync(join(g, '8e3d6-0', 'package.json'), '{}', { flag: 'w' });
      link(join(pkgs, '@playwright', 'cli'), join(g, '8e3d6-0', 'node_modules', '@playwright', 'cli'));
    },
    'pnpm v11, direct': (g, store) => {
      writeStub(join(store, 'pw', 'node_modules', 'playwright'));
      link(join(store, 'pw', 'node_modules', 'playwright'), join(g, 'abc-0', 'node_modules', 'playwright'));
    },
    // A flat npm install must win over a pnpm v11 package's transitive playwright-core.
    'npm flat beside pnpm v11': (g, store, dir) => {
      writeStub(join(dir, 'npm-global', 'playwright'));
      mkdirSync(join(store, 'other', 'node_modules', 'other'), { recursive: true });
      writeFileSync(join(store, 'other', 'node_modules', 'other', 'package.json'), '{"name":"other"}');
      writeStub(join(store, 'other', 'node_modules', 'playwright-core'));
      link(join(store, 'other', 'node_modules', 'other'), join(g, '8e3d6-0', 'node_modules', 'other'));
      return { npmRoot: join(dir, 'npm-global'), expect: join('npm-global', 'playwright') };
    },
  };
  for (const [label, build] of Object.entries(layouts)) {
    const dir = mkdtempSync(join(tmpdir(), 'drawio-layout-test-'));
    try {
      const global = join(dir, 'global');
      const store = join(dir, 'store');
      mkdirSync(join(global, '8e3d6-0'), { recursive: true });
      const { npmRoot, expect } = build(global, store, dir) ?? {};
      const copy = join(dir, 'bin', 'render-drawio.mjs');
      mkdirSync(dirname(copy));
      copyFileSync(renderer, copy);
      const stub = join(dir, 'preload.mjs');
      // pnpm reports the fake global root; npm reports its own root, or behaves as missing with a
      // shell-style error on stderr.
      writeFileSync(stub, `
        import cp from 'node:child_process';
        import { syncBuiltinESMExports } from 'node:module';
        const real = cp.execSync;
        cp.execSync = (cmd, opts) => cmd.startsWith('pnpm ') ? ${JSON.stringify(global)}
          : ${JSON.stringify(npmRoot ?? null)} ?? real(${JSON.stringify(JSON.stringify(process.execPath))} + ' -e "process.stderr.write(\\'npm: command not found\\'); process.exit(127)"', opts);
        syncBuiltinESMExports();
      `);
      const file = join(dir, 'input.drawio');
      writeFileSync(file, '<mxfile><diagram name="P"><mxGraphModel/></diagram></mxfile>');
      const loadLog = join(dir, 'loaded.txt');
      const result = spawnSync(process.execPath, ['--import', stub, copy, file, '--out', join(dir, 'out')], {
        encoding: 'utf8', timeout: 10000, cwd: dir,
        env: { ...process.env, NODE_OPTIONS: '', NODE_PATH: '', PLAYWRIGHT_BROWSERS_PATH: '0', RENDER_LOG: join(dir, 'shots.jsonl'), LOAD_LOG: loadLog },
      });
      assert.ifError(result.error);
      assert.equal(result.status, 0, `${label}: ${result.stderr}`);
      assert.ok(existsSync(loadLog), `${label}: playwright stub was not loaded`);
      assert.ok(existsSync(join(dir, 'out', 'P.png')), `${label}: no PNG written`);
      if (expect) assert.ok(readFileSync(loadLog, 'utf8').includes(expect), `${label}: loaded ${readFileSync(loadLog, 'utf8')}`);
      assert.doesNotMatch(result.stderr, /command not found/, `${label}: a missing npm must stay quiet`);
    } finally {
      rmSync(dir, { recursive: true, force: true });
    }
  }
  console.log(`drawio renderer: ${Object.keys(layouts).length} global Playwright layouts resolved`);
} finally {
  rmSync(root, { recursive: true, force: true });
}
