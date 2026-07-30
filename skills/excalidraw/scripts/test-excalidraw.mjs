#!/usr/bin/env node

import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const cli = join(scriptDir, "excalidraw.mjs");
const example = resolve(scriptDir, "..", "examples", "visual-review-loop.scene.json");
const workspace = mkdtempSync(join(tmpdir(), "excalidraw-skill-test-"));

function run(args, expectedStatus = 0) {
  const result = spawnSync(process.execPath, [cli, ...args], {
    cwd: tmpdir(),
    encoding: "utf8",
  });
  assert.equal(
    result.status,
    expectedStatus,
    `Expected exit ${expectedStatus}, got ${result.status}\nstdout:\n${result.stdout}\nstderr:\n${result.stderr}`,
  );
  return `${result.stdout}\n${result.stderr}`;
}

try {
  const native = join(workspace, "scene.excalidraw");
  const svg = join(workspace, "scene.svg");

  const buildOutput = run(["build", example, native]);
  assert.match(buildOutput, /STRUCTURALLY VALID/);
  assert.match(buildOutput, /0 warnings/);

  const defaultSpec = join(workspace, "default-name.scene.json");
  writeFileSync(defaultSpec, readFileSync(example, "utf8"), "utf8");
  run(["build", defaultSpec]);
  assert.match(
    readFileSync(join(workspace, "default-name.excalidraw"), "utf8"),
    /"type": "excalidraw"/,
  );

  const darkNative = JSON.parse(readFileSync(native, "utf8"));
  assert.equal(darkNative.appState.viewBackgroundColor, "#000000");
  assert.equal(darkNative.appState.theme, "dark");
  assert.equal(
    darkNative.elements.find((element) => element.id === "scene").backgroundColor,
    "#1e3a5f",
  );
  assert.equal(darkNative.elements.find((element) => element.id === "correction-loop").roundness.type, 2);

  const validateOutput = run(["validate", native]);
  assert.match(validateOutput, /STRUCTURALLY VALID/);

  const previewOutput = run(["preview", native, svg]);
  assert.match(previewOutput, /LAYOUT PREVIEW SVG/);
  assert.match(readFileSync(svg, "utf8"), /<svg/);

  const scene = JSON.parse(readFileSync(native, "utf8"));
  const brokenBinding = structuredClone(scene);
  const source = brokenBinding.elements.find((element) => element.id === "brief");
  source.boundElements = source.boundElements.filter((entry) => entry.id !== "brief-to-scene");
  const brokenPath = join(workspace, "broken-binding.excalidraw");
  writeFileSync(brokenPath, JSON.stringify(brokenBinding), "utf8");
  assert.match(run(["validate", brokenPath], 1), /not reciprocally bound/);

  const duplicate = structuredClone(scene);
  duplicate.elements.at(-1).id = duplicate.elements[0].id;
  const duplicatePath = join(workspace, "duplicate.excalidraw");
  writeFileSync(duplicatePath, JSON.stringify(duplicate), "utf8");
  assert.match(run(["validate", duplicatePath], 1), /Duplicate element id/);

  const badNumberSpec = JSON.parse(readFileSync(example, "utf8"));
  badNumberSpec.nodes[0].x = "80";
  const badNumberPath = join(workspace, "bad-number.scene.json");
  writeFileSync(badNumberPath, JSON.stringify(badNumberSpec), "utf8");
  assert.match(run(["build", badNumberPath], 1), /nodes\[0\]\.x must be a finite number/);

  const badRouteSpec = JSON.parse(readFileSync(example, "utf8"));
  badRouteSpec.edges[0].route = [["300", 260]];
  const badRoutePath = join(workspace, "bad-route.scene.json");
  writeFileSync(badRoutePath, JSON.stringify(badRouteSpec), "utf8");
  assert.match(
    run(["build", badRoutePath], 1),
    /edges\[0\]\.route\[0\] must contain two finite numbers/,
  );

  const badLineSpec = JSON.parse(readFileSync(example, "utf8"));
  badLineSpec.lines[0].points[0][0] = "1120";
  const badLinePath = join(workspace, "bad-line.scene.json");
  writeFileSync(badLinePath, JSON.stringify(badLineSpec), "utf8");
  assert.match(
    run(["build", badLinePath], 1),
    /lines\[0\]\.points\[0\] must contain two finite numbers/,
  );

  const missingImage = structuredClone(scene);
  missingImage.elements.push({
    id: "missing-image",
    type: "image",
    x: 0,
    y: 0,
    width: 100,
    height: 100,
    isDeleted: false
  });
  const missingImagePath = join(workspace, "missing-image.excalidraw");
  writeFileSync(missingImagePath, JSON.stringify(missingImage), "utf8");
  assert.match(run(["validate", missingImagePath], 1), /image without fileId/);

  const crossing = structuredClone(scene);
  crossing.elements.push({
    id: "blocking-node",
    type: "rectangle",
    x: 290,
    y: 220,
    width: 40,
    height: 90,
    strokeColor: "#000000",
    backgroundColor: "transparent",
    strokeWidth: 1,
    strokeStyle: "solid",
    roughness: 0,
    opacity: 100,
    angle: 0,
    isDeleted: false,
    boundElements: null
  });
  const crossingPath = join(workspace, "crossing.excalidraw");
  writeFileSync(crossingPath, JSON.stringify(crossing), "utf8");
  assert.match(run(["validate", crossingPath]), /crosses blocking-node/);

  const wide = structuredClone(scene);
  wide.elements.find((element) => element.id === "status-note").x = 5000;
  const widePath = join(workspace, "wide.excalidraw");
  const wideSvgPath = join(workspace, "wide.svg");
  writeFileSync(widePath, JSON.stringify(wide), "utf8");
  run(["preview", widePath, wideSvgPath]);
  const wideSvg = readFileSync(wideSvgPath, "utf8");
  assert.match(wideSvg, /width="1800"/);
  const viewBoxWidth = Number(wideSvg.match(/viewBox="[^"]+ [^"]+ ([^"]+) [^"]+"/)[1]);
  const backgroundWidth = Number(wideSvg.match(/<rect[^>]+width="([^"]+)"/)[1]);
  assert.equal(backgroundWidth, viewBoxWidth);

  console.log(
    "PASS: build, validate, preview scaling, numeric rejection, image files, bindings, IDs, and crossings.",
  );
} finally {
  rmSync(workspace, { recursive: true, force: true });
}
