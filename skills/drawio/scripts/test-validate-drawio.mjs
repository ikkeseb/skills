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

const objectCells = `
  <root>
    <mxCell id="0"/>
    <mxCell id="1" parent="0"/>
    <object id="n1" label="X" myprop="1">
      <mxCell style="rounded=1" vertex="1" parent="1">
        <mxGeometry x="0" y="0" width="120" height="60" as="geometry"/>
      </mxCell>
    </object>
    <object id="n2" label="Y">
      <mxCell style="rounded=1" vertex="1" parent="1">
        <mxGeometry x="200" y="0" width="120" height="60" as="geometry"/>
      </mxCell>
    </object>
    <object id="n1-to-n2" label="calls" myprop="2">
      <mxCell style="" edge="1" parent="1" source="n1" target="n2">
        <mxGeometry relative="1" as="geometry"/>
      </mxCell>
    </object>
  </root>`;

const raw = `<mxGraphModel>${cells}</mxGraphModel>`;
const objectWrapped = `<mxGraphModel>${objectCells}</mxGraphModel>`;
const userObjectWrapped = objectWrapped.replace(/<object /g, "<UserObject ").replace(/<\/object>/g, "</UserObject>");
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
assert.deepEqual(validateDocument(objectWrapped), { pages: 1, cells: 5 });
assert.deepEqual(validateDocument(userObjectWrapped), { pages: 1, cells: 5 });
assert.deepEqual(
  validateDocument(wrapped.replace(`<mxGraphModel>${cells}</mxGraphModel>`, objectWrapped)),
  { pages: 1, cells: 5 },
);

const invalidCases = [
  ["comment", raw.replace("<root>", "<!-- hidden --><root>"), /comments are not allowed/],
  ["duplicate id", raw.replace('id="b"', 'id="a"'), /duplicate mxCell id a/],
  ["unknown target", raw.replace('target="b"', 'target="missing"'), /unknown target/],
  ["edge geometry", raw.replace('relative="1" x="-0.25"', 'x="-0.25"'), /relative=1/],
  ["missing layer", raw.replace('<mxCell id="1" parent="0"/>', ""), /missing default layer/],
  ["unknown root child", raw.replace("<root>", "<root><mxSomething/>"), /unsupported child <mxSomething>/],
  ["wrapper without mxCell", raw.replace("<root>", '<root><object id="ignored"/>'), /<object> needs exactly one mxCell child/],
  ["wrapper duplicate id", objectWrapped.replace('id="n2"', 'id="n1"'), /duplicate mxCell id n1/],
  ["wrapper without id", objectWrapped.replace('id="n1" label="X"', 'label="X"'), /every <object> needs an id/],
  ["wrapper unknown target", objectWrapped.replace('target="n2"', 'target="missing"'), /unknown target/],
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

console.log(`PASS: ${9 + invalidCases.length} draw.io validator cases`);
