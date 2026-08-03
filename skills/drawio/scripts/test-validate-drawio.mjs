#!/usr/bin/env node

import assert from "node:assert/strict";
import { mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { dirname, join } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { validateDocument } from "./validate-drawio.mjs";

const cells = `
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>
    <mxCell id="a" value="A &amp; B" vertex="1" parent="1">
      <mxGeometry x="20" y="20" width="120" height="60" as="geometry"/>
    </mxCell>
    <mxCell id="b" value="B" vertex="1" parent="1">
      <mxGeometry x="220" y="20" width="120" height="60" as="geometry"/>
    </mxCell>
    <mxCell id="a-to-b" value="calls" edge="1" parent="1" source="a" target="b">
      <mxGeometry relative="1" x="-0.25" as="geometry"/>
    </mxCell>
  </root>`;

const raw = `<mxGraphModel>${cells}</mxGraphModel>`;
const wrapped = `<?xml version="1.0" encoding="UTF-8"?>
<mxfile host="app.diagrams.net" compressed="false">
  <diagram id="page-1" name="Page-1"><mxGraphModel>${cells}</mxGraphModel></diagram>
</mxfile>`;
const multiPage = wrapped.replace(
  "</mxfile>",
  `<diagram id="page-2" name="Page-2"><mxGraphModel>${cells}</mxGraphModel></diagram></mxfile>`,
);
const withWaypoint = raw.replace(
  'relative="1" x="-0.25" as="geometry"/',
  'relative="1" as="geometry"><Array as="points"><mxPoint x="180" y="90"/></Array></mxGeometry',
);

assert.deepEqual(validateDocument(raw), { pages: 1, cells: 5 });
assert.deepEqual(validateDocument(wrapped), { pages: 1, cells: 5 });
assert.deepEqual(validateDocument(multiPage), { pages: 2, cells: 10 });
assert.deepEqual(validateDocument(withWaypoint), { pages: 1, cells: 5 });

const invalidCases = [
  ["comment", raw.replace("<root>", "<!-- hidden --><root>"), /comments are not allowed/],
  ["duplicate id", raw.replace('id="b"', 'id="a"'), /duplicate mxCell id a/],
  ["unknown target", raw.replace('target="b"', 'target="missing"'), /unknown target/],
  ["edge geometry", raw.replace('relative="1" x="-0.25"', 'x="-0.25"'), /relative=1/],
  ["missing layer", raw.replace('<mxCell id="1" parent="0"/>', ""), /missing default layer/],
  ["unvalidated wrapper", raw.replace("<root>", '<root><object id="ignored"/>'), /unsupported child <object>/],
  ["bad entity", raw.replace("A &amp; B", "A & B"), /invalid & entity/],
  ["bad geometry", raw.replace('width="120"', 'width="0"'), /must be positive/],
  ["missing geometry role", raw.replace('as="geometry"', 'as="other"'), /needs as=geometry/],
  ["bad waypoint", raw.replace('relative="1" x="-0.25" as="geometry"/', 'relative="1" as="geometry"><Array as="points"><mxPoint x="NaN" y="20"/></Array></mxGeometry'), /mxPoint needs numeric/],
  ["compressed", wrapped.replace('compressed="false"', 'compressed="true"'), /must be uncompressed/],
  ["duplicate page id", multiPage.replace('id="page-2"', 'id="page-1"'), /duplicate diagram id/],
  ["mismatched tag", raw.replace("</root>", "</mxfile>"), /does not match/],
];

for (const [name, xml, expected] of invalidCases) {
  assert.throws(() => validateDocument(xml), expected, name);
}

const tempRoot = await mkdtemp(join(tmpdir(), "drawio-validator-"));
try {
  const validPath = join(tempRoot, "valid.drawio");
  const invalidPath = join(tempRoot, "invalid.drawio");
  await writeFile(validPath, wrapped);
  await writeFile(invalidPath, raw.replace('target="b"', 'target="missing"'));
  const scriptPath = join(dirname(fileURLToPath(import.meta.url)), "validate-drawio.mjs");

  const pass = spawnSync(process.execPath, [scriptPath, validPath], { encoding: "utf8" });
  assert.equal(pass.status, 0, pass.stderr);
  assert.match(pass.stdout, /PASS .*valid\.drawio: 1 page\(s\), 5 cell\(s\)/);

  const fail = spawnSync(process.execPath, [scriptPath, invalidPath], { encoding: "utf8" });
  assert.equal(fail.status, 1);
  assert.match(fail.stderr, /unknown target/);
} finally {
  await rm(tempRoot, { recursive: true, force: true });
}

console.log(`PASS: ${6 + invalidCases.length} draw.io validator cases`);
