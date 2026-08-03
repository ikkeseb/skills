#!/usr/bin/env node

import assert from "node:assert/strict";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { dirname, join, resolve, win32 as win32Path } from "node:path";
import { spawnSync } from "node:child_process";
import { fileURLToPath } from "node:url";
import { browserCandidates, findBrowser, pngFromSvg } from "./excalidraw.mjs";

const scriptDir = dirname(fileURLToPath(import.meta.url));
const cli = join(scriptDir, "excalidraw.mjs");
const example = resolve(scriptDir, "..", "examples", "visual-review-loop.scene.json");
const palette = JSON.parse(
  readFileSync(resolve(scriptDir, "..", "references", "palette.json"), "utf8"),
);
const semanticTones = [
  "ai",
  "data",
  "decision",
  "external",
  "human",
  "inactive",
  "primary",
  "secondary",
  "start",
  "success",
  "tertiary",
  "warning",
];
assert.deepEqual(Object.keys(palette.semantic.light).sort(), semanticTones);
assert.deepEqual(Object.keys(palette.semantic.dark).sort(), semanticTones);
function assertColorTree(value, path = "palette") {
  if (typeof value === "string") {
    assert.match(value, /^#[0-9a-f]{6}$/i, `${path} must be a six-digit hex color.`);
    return;
  }
  for (const [key, child] of Object.entries(value)) {
    assertColorTree(child, `${path}.${key}`);
  }
}
assertColorTree(palette);
assert.doesNotMatch(
  readFileSync(resolve(scriptDir, "..", "references", "color-palette.md"), "utf8"),
  /#[0-9a-f]{6}/i,
  "Keep exact tokens in references/palette.json, not the usage guide.",
);
assert.doesNotMatch(
  readFileSync(cli, "utf8"),
  /#[0-9a-f]{6}/i,
  "Keep default colors in references/palette.json, not the builder.",
);
const workspace = mkdtempSync(join(tmpdir(), "excalidraw-skill-test-"));

function run(args, expectedStatus = 0, options = {}) {
  const result = spawnSync(process.execPath, [cli, ...args], {
    cwd: tmpdir(),
    encoding: "utf8",
    env: { ...process.env, ...options.env },
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

  const writeFailure = run(["build", example, workspace], 1);
  assert.match(writeFailure, /Could not write JSON/);
  assert.doesNotMatch(writeFailure, /STRUCTURALLY VALID/);

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
  const scene = darkNative;

  const validateOutput = run(["validate", native]);
  assert.match(validateOutput, /STRUCTURALLY VALID/);

  const previewOutput = run(["preview", native, svg]);
  assert.match(previewOutput, /LAYOUT PREVIEW SVG/);
  assert.match(readFileSync(svg, "utf8"), /<svg/);

  const checkPng = join(workspace, "check.png");
  const checkOutput = run(["check", native, checkPng], 2, {
    env: {
      LOCALAPPDATA: join(workspace, "local-app-data"),
      ProgramFiles: join(workspace, "program-files"),
      "ProgramFiles(x86)": join(workspace, "program-files-x86"),
      PATH: workspace,
    },
  });
  assert.match(checkOutput, /LAYOUT PREVIEW SVG/);
  assert.match(checkOutput, /Layout PNG unavailable/);
  assert.match(checkOutput, /NATIVE VISUALLY UNVERIFIED/);
  assert.match(readFileSync(join(workspace, "scene.layout.svg"), "utf8"), /<svg/);

  const syntheticPng = join(workspace, "synthetic.png");
  let browserInvocation;
  const pngResult = pngFromSvg(svg, syntheticPng, { width: 320.2, height: 199.1 }, {
    browser: "fake-browser",
    spawn(browser, args) {
      browserInvocation = { browser, args };
      writeFileSync(syntheticPng, Buffer.from("89504e470d0a1a0a", "hex"));
      return { status: 0, stdout: "", stderr: "" };
    },
  });
  assert.deepEqual(pngResult, { ok: true, width: 321, height: 200 });
  assert.equal(browserInvocation.browser, "fake-browser");
  assert.ok(browserInvocation.args.includes(`--screenshot=${resolve(syntheticPng)}`));
  assert.equal(readFileSync(syntheticPng).subarray(0, 8).toString("hex"), "89504e470d0a1a0a");

  const windowsEnv = {
    LOCALAPPDATA: "C:\\Users\\tester\\AppData\\Local",
    ProgramFiles: "C:\\Program Files",
    "ProgramFiles(x86)": "C:\\Program Files (x86)",
  };
  const localChrome = win32Path.join(
    windowsEnv.LOCALAPPDATA,
    "Google",
    "Chrome",
    "Application",
    "chrome.exe",
  );
  const localEdge = win32Path.join(
    windowsEnv.LOCALAPPDATA,
    "Microsoft",
    "Edge",
    "Application",
    "msedge.exe",
  );
  const candidates = browserCandidates("win32", windowsEnv);
  assert.ok(candidates.includes(localChrome));
  assert.ok(candidates.includes(localEdge));
  assert.ok(candidates.includes("chrome.exe"));
  assert.ok(candidates.includes("msedge.exe"));
  assert.equal(
    findBrowser({
      platform: "win32",
      env: windowsEnv,
      fileExists: (candidate) => candidate === localChrome,
      locate: () => null,
    }),
    localChrome,
  );
  assert.equal(
    findBrowser({
      platform: "win32",
      env: windowsEnv,
      fileExists: () => false,
      locate: (candidate) => candidate === "msedge.exe" ? "C:\\Tools\\msedge.exe" : null,
    }),
    "C:\\Tools\\msedge.exe",
  );

  for (const theme of ["dark", "light"]) {
    const themeSpec = {
      theme,
      title: `${theme} theme`,
      sections: [
        { id: "background", x: 20, y: 120, width: 620, height: 260 },
      ],
      nodes: [
        { id: "source", text: "Source", x: 80, y: 180, width: 160, height: 80 },
        { id: "target", text: "Target", x: 400, y: 180, width: 160, height: 80 },
      ],
      edges: [{ id: "source-to-target", from: "source", to: "target" }],
      lines: [{ id: "divider", points: [[60, 320], [600, 320]] }],
    };
    const themeSpecPath = join(workspace, `${theme}.scene.json`);
    const themeNativePath = join(workspace, `${theme}.excalidraw`);
    writeFileSync(themeSpecPath, JSON.stringify(themeSpec), "utf8");
    run(["build", themeSpecPath, themeNativePath]);
    const themeNative = JSON.parse(readFileSync(themeNativePath, "utf8"));
    assert.equal(themeNative.appState.theme, theme);
    assert.equal(themeNative.appState.viewBackgroundColor, palette.canvas[theme]);
    assert.equal(
      themeNative.elements.find((element) => element.id === "source").backgroundColor,
      palette.semantic[theme].primary.fill,
    );
    assert.equal(
      themeNative.elements.find((element) => element.id === "divider").strokeColor,
      palette.lines[theme].structural,
    );
    assert.equal(
      themeNative.elements.find((element) => element.id === "scene-title").strokeColor,
      palette.text[theme].title,
    );
    assert.equal(
      themeNative.elements.find((element) => element.id === "source-label").strokeColor,
      palette.text[theme].body,
    );
  }

  const customCanvasSpec = {
    theme: "light",
    canvasBackground: "#123456",
    nodes: [{ id: "only-node", x: 0, y: 0, width: 100, height: 80 }],
  };
  const customCanvasPath = join(workspace, "custom-canvas.scene.json");
  const customCanvasNativePath = join(workspace, "custom-canvas.excalidraw");
  writeFileSync(customCanvasPath, JSON.stringify(customCanvasSpec), "utf8");
  run(["build", customCanvasPath, customCanvasNativePath]);
  assert.equal(
    JSON.parse(readFileSync(customCanvasNativePath, "utf8")).appState.viewBackgroundColor,
    "#123456",
  );

  const sectionEdgeSpec = {
    sections: [{ id: "background", x: 0, y: 0, width: 400, height: 300 }],
    nodes: [{ id: "node", x: 100, y: 100, width: 120, height: 80 }],
    edges: [{ id: "invalid-edge", from: "node", to: "background" }],
  };
  const sectionEdgePath = join(workspace, "section-edge.scene.json");
  writeFileSync(sectionEdgePath, JSON.stringify(sectionEdgeSpec), "utf8");
  assert.match(run(["build", sectionEdgePath], 1), /must connect existing nodes/);

  const sectionBinding = structuredClone(scene);
  const section = sectionBinding.elements.find(
    (element) => element.customData?.excalidrawSkill?.role === "section",
  );
  const boundArrow = sectionBinding.elements.find((element) => element.type === "arrow" && element.endBinding);
  const oldTarget = sectionBinding.elements.find(
    (element) => element.id === boundArrow.endBinding.elementId,
  );
  oldTarget.boundElements = oldTarget.boundElements.filter((entry) => entry.id !== boundArrow.id);
  section.boundElements = [...(section.boundElements ?? []), { id: boundArrow.id, type: "arrow" }];
  boundArrow.endBinding.elementId = section.id;
  const sectionBindingPath = join(workspace, "section-binding.excalidraw");
  writeFileSync(sectionBindingPath, JSON.stringify(sectionBinding), "utf8");
  assert.match(run(["validate", sectionBindingPath], 1), /must bind to a node, not section/);

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
    "PASS: build/write failures, validate, check, PNG path, browser discovery, themes, section edges, scaling, numeric rejection, image files, bindings, IDs, and crossings.",
  );
} finally {
  rmSync(workspace, { recursive: true, force: true });
}
