// still.mjs: render single frames of the reel to PNG, straight from file:// (no server).
// usage: node still.mjs <outdir> <t1> [t2 ...] [--query "s3=s3b&music=b"] [--blur 8]
// writes <outdir>/<t>.png per time (seconds). Needs Playwright: playwright(-core) resolvable, or PW_MODULE=<path>.
import { mkdirSync } from 'node:fs';
import { createRequire } from 'node:module';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';

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
const flagVals = new Set(['--query', '--blur'].flatMap(f => { const i = args.indexOf(f); return i >= 0 ? [i, i + 1] : []; }));
const pos = args.filter((a, i) => !a.startsWith('--') && !flagVals.has(i));
const [outdir, ...times] = pos;
if (!outdir || !times.length) { console.error('usage: node still.mjs <outdir> <t1> [t2 ...] [--query "a=b&c=d"] [--blur 8]'); process.exit(2); }
const blur = parseInt(opt('blur', '1'), 10), query = opt('query', '');
mkdirSync(outdir, { recursive: true });

const here = dirname(fileURLToPath(import.meta.url));
const url = `${pathToFileURL(join(here, 'index.html')).href}?t=0&${query}`;

const browser = await chromium.launch({ args: ['--allow-file-access-from-files'] });
const page = await browser.newPage({ viewport: { width: 1920, height: 1080 } });
const errors = [];
page.on('pageerror', e => errors.push(e.message));
page.on('console', m => m.type() === 'error' && errors.push(m.text()));
await page.goto(url);
await page.waitForSelector('body[data-ready="1"]');
const canvas = await page.$('canvas');
for (const t of times) {
  await page.evaluate(([tt, b]) => REEL.renderAt(tt, { blur: b }), [parseFloat(t), blur]);
  const file = resolve(outdir, `${t}.png`);
  await canvas.screenshot({ type: 'png', path: file });
  console.log(file);
}
await browser.close();
console.log(errors.length ? `page errors:\n${[...new Set(errors)].join('\n')}` : 'no page errors');
