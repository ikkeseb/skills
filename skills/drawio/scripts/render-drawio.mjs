#!/usr/bin/env node
/**
 * Headless .drawio -> PNG renderer for visual verification.
 *
 * Renders one or more pages of a .drawio file to high-res PNGs using
 * Playwright Chromium + the official diagrams.net viewer
 * (viewer.diagrams.net/js/viewer-static.min.js) — same rendering engine as
 * app.diagrams.net, so sketch=1 and label placement are faithful.
 *
 * Accepts both mxfile documents (multi-page) and a raw single-page
 * mxGraphModel (wrapped into one page automatically).
 *
 * Usage:
 *   node render-drawio.mjs <file.drawio> [--out <dir>] [--pages <substr,substr,...>]
 *                          [--scale <n>] [--bg white|transparent] [--timeout <ms>]
 *
 *   --pages   comma-separated substrings matched against page names
 *             (e.g. "flow,landscape"). Default: all pages.
 *   --out     output directory (default: ./render next to the input file)
 *   --scale   device pixel ratio, i.e. resolution multiplier (default 2.5)
 *   --bg      "white" (inspection — edges/labels clearly visible) or
 *             "transparent" (deliverable exports). Default: white.
 *
 * Prerequisites: Node + Playwright (or playwright-core) with Chromium, and
 * network access to viewer.diagrams.net (one JS file; cached by Chromium).
 * Offline fallback: draw.io Desktop CLI
 *   drawio -x -f png -t -s 2.5 --page-index <N> -o out.png file.drawio
 */
import { createRequire } from 'node:module';
import { execSync } from 'node:child_process';
import { readFileSync, readdirSync, mkdirSync } from 'node:fs';
import { resolve, dirname, join } from 'node:path';
import { homedir } from 'node:os';

const require = createRequire(import.meta.url);

// Some agent sandboxes (e.g. Cursor's shell wrapper) inject PLAYWRIGHT_BROWSERS_PATH
// pointing at an empty per-session cache. If the override holds no Chromium but the
// default cache does, ignore the override instead of failing the launch.
{
  const override = process.env.PLAYWRIGHT_BROWSERS_PATH;
  if (override && override !== '0') {
    const home = homedir();
    const dflt = process.platform === 'win32'
      ? join(process.env.LOCALAPPDATA ?? join(home, 'AppData', 'Local'), 'ms-playwright')
      : process.platform === 'darwin'
        ? join(home, 'Library', 'Caches', 'ms-playwright')
        : join(home, '.cache', 'ms-playwright');
    const hasChromium = (dir) => {
      try { return readdirSync(dir).some(n => n.startsWith('chromium')); } catch { return false; }
    };
    if (!hasChromium(override) && hasChromium(dflt)) delete process.env.PLAYWRIGHT_BROWSERS_PATH;
  }
}

function loadPlaywright() {
  const candidates = ['playwright', 'playwright-core'];
  for (const pm of ['pnpm', 'npm']) {
    try {
      const root = execSync(`${pm} root -g`, { encoding: 'utf-8' }).trim();
      for (const p of ['playwright', 'playwright-core',
                       '@playwright/cli/node_modules/playwright',
                       '@playwright/cli/node_modules/playwright-core']) {
        candidates.push(join(root, p));
      }
    } catch { /* package manager not available; try the next one */ }
  }
  for (const c of candidates) {
    try { return require(c); } catch { /* try next */ }
  }
  console.error('ERROR: playwright not found. Install with: pnpm add -g playwright && pnpm exec playwright install chromium');
  process.exit(2);
}

// ---- args -------------------------------------------------------------------
const argv = process.argv.slice(2);
if (!argv.length || argv[0].startsWith('--')) {
  console.error('usage: node render-drawio.mjs <file.drawio> [--out dir] [--pages a,b] [--scale 2.5] [--bg white|transparent]');
  process.exit(1);
}
const file = resolve(argv[0]);
const opt = (name, dflt) => {
  const i = argv.indexOf('--' + name);
  return i >= 0 && argv[i + 1] ? argv[i + 1] : dflt;
};
const outDir = resolve(opt('out', join(dirname(file), 'render')));
const pageFilter = opt('pages', '').split(',').map(s => s.trim()).filter(Boolean);
const scale = parseFloat(opt('scale', '2.5'));
const timeout = parseInt(opt('timeout', '30000'), 10);
const bg = opt('bg', 'white') === 'transparent' ? 'transparent' : 'white';

// ---- read pages -------------------------------------------------------------
let xml = readFileSync(file, 'utf-8');
if (/<diagram[^>]*>[A-Za-z0-9+/=\s]{40,}<\/diagram>/.test(xml)) {
  console.error('ERROR: file uses compressed page content. Re-save uncompressed ' +
    '(File > Properties > Compressed off) or export via draw.io Desktop.');
  process.exit(1);
}
let pageNames = [...xml.matchAll(/<diagram[^>]*\bname="([^"]*)"/g)].map(m => m[1]);
if (!pageNames.length) {
  if (/<mxGraphModel[\s>]/.test(xml)) {
    // Raw single-page mxGraphModel — wrap it so the viewer sees one page.
    xml = `<mxfile><diagram name="Page-1">${xml}</diagram></mxfile>`;
    pageNames = ['Page-1'];
  } else {
    console.error('ERROR: no <diagram> pages or <mxGraphModel> found in ' + file);
    process.exit(1);
  }
}
const wanted = pageNames
  .map((name, idx) => ({ name, idx }))
  .filter(p => !pageFilter.length || pageFilter.some(f => p.name.includes(f)));
if (!wanted.length) {
  console.error(`ERROR: no pages match [${pageFilter}]. Pages: ${pageNames.join(' | ')}`);
  process.exit(1);
}

// ---- render -----------------------------------------------------------------
const { chromium } = loadPlaywright();

const htmlFor = (pageIdx) => {
  const cfg = JSON.stringify({
    xml, page: pageIdx, resize: true, nav: false,
  }).replace(/&/g, '&amp;').replace(/'/g, '&#39;');
  return `<!doctype html><html><head><meta charset="utf-8">
<style>html,body{margin:0;padding:0;background:${bg};}</style></head>
<body><div class="mxgraph" data-mxgraph='${cfg}'></div>
<script src="https://viewer.diagrams.net/js/viewer-static.min.js"></script>
</body></html>`;
};

mkdirSync(outDir, { recursive: true });
const safe = (s) => s.replace(/[^A-Za-z0-9._-]+/g, '_');

const browser = await chromium.launch();
try {
  const ctx = await browser.newContext({
    viewport: { width: 2600, height: 1600 },
    deviceScaleFactor: scale,
  });
  for (const p of wanted) {
    const page = await ctx.newPage();
    page.on('pageerror', e => console.error(`[pageerror ${p.name}]`, String(e).slice(0, 300)));
    page.on('requestfailed', r => console.error(`[requestfailed] ${r.url().slice(0, 120)} ${r.failure()?.errorText ?? ''}`));
    await page.setContent(htmlFor(p.idx), { waitUntil: 'networkidle', timeout });
    await page.waitForSelector('.mxgraph svg', { state: 'attached', timeout });
    await page.waitForTimeout(600); // let sketch strokes/fonts settle
    const out = join(outDir, safe(p.name) + '.png');
    await page.locator('.mxgraph svg').first().screenshot({
      path: out, omitBackground: bg === 'transparent', timeout,
    });
    console.log(`rendered page ${p.idx} "${p.name}" -> ${out}`);
    await page.close();
  }
} finally {
  await browser.close();
}
