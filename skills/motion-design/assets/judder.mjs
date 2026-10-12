// judder.mjs: find where a rendered reel jumps or strobes. Measures the mean frame-to-frame
// difference and lists frames far above the median that are not on a cut.
// usage: node judder.mjs <reel.mp4> --bpm 140 [--factor 6] [--floor 4]
import { execFileSync } from 'node:child_process';
import { readFileSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const args = process.argv.slice(2);
const opt = (name, def) => { const i = args.indexOf(`--${name}`); return i >= 0 ? args[i + 1] : def; };
const file = args.find(a => !a.startsWith('--') && /\.(mp4|mov|webm)$/.test(a));
const bar = 240 / parseFloat(opt('bpm', '120'));
const factor = parseFloat(opt('factor', '6')), floor = parseFloat(opt('floor', '4'));

const fps = execFileSync('ffprobe', ['-v', 'error', '-select_streams', 'v:0', '-show_entries', 'stream=r_frame_rate',
  '-of', 'csv=p=0', file]).toString().trim().split('/').reduce((a, b) => a / b);
const log = join(mkdtempSync(join(tmpdir(), 'judder-')), 'diff.txt');
execFileSync('ffmpeg', ['-loglevel', 'error', '-i', file, '-vf',
  `scale=480:-1,tblend=all_mode=difference,signalstats,metadata=print:key=lavfi.signalstats.YAVG:file=${log}`,
  '-f', 'null', '-']);
const d = [...readFileSync(log, 'utf8').matchAll(/YAVG=([\d.]+(?:e[-+]?\d+)?)/g)].map(m => +m[1]);
const med = [...d].sort((a, b) => a - b)[d.length >> 1];
const limit = Math.max(floor, factor * med);

// group consecutive flagged frames into runs; a long run is strobing motion, a short one a jump
const runs = [];
d.forEach((v, i) => {
  const t = (i + 1) / fps;
  const onCut = Math.abs(t / bar - Math.round(t / bar)) * bar < 1.5 / fps;
  if (v <= limit || onCut) return;
  const r = runs[runs.length - 1];
  if (r && i - r.end <= 2) { r.end = i; r.max = Math.max(r.max, v); } else runs.push({ start: i, end: i, max: v });
});
console.log(`${file}: ${d.length} frames at ${+fps.toFixed(2)} fps, median diff ${med.toFixed(2)}, limit ${limit.toFixed(2)}`);
for (const r of runs) {
  const a = (r.start + 1) / fps, z = (r.end + 1) / fps, len = r.end - r.start + 1;
  console.log(`${a.toFixed(2)}–${z.toFixed(2)} s  ${len} frame(s)  peak ${r.max.toFixed(1)}  ${len > 6 ? 'sustained: fast motion strobing' : 'jump: a pop or a discontinuity'}`);
}
if (!runs.length) console.log('no jumps outside cuts');
