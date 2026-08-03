#!/usr/bin/env node

import { execFileSync, spawnSync } from "node:child_process";
import { existsSync, readFileSync, realpathSync, writeFileSync } from "node:fs";
import { basename, dirname, extname, isAbsolute, resolve, win32 as win32Path } from "node:path";
import { fileURLToPath, pathToFileURL } from "node:url";

const PALETTE_TOKENS = readJson(
  fileURLToPath(new URL("../references/palette.json", import.meta.url)),
);
const PALETTE = PALETTE_TOKENS.semantic.light;
const DARK_PALETTE = PALETTE_TOKENS.semantic.dark;

const SUPPORTED_TYPES = new Set([
  "arrow",
  "diamond",
  "ellipse",
  "frame",
  "image",
  "line",
  "rectangle",
  "text",
]);

const SHAPE_TYPES = new Set(["diamond", "ellipse", "frame", "rectangle"]);
const LINE_TYPES = new Set(["arrow", "line"]);
const FONT_FAMILY = {
  1: '"Virgil", "Comic Sans MS", cursive',
  2: 'Helvetica, Arial, sans-serif',
  3: '"Cascadia Code", "SFMono-Regular", Consolas, monospace',
  5: '"Excalifont", "Comic Sans MS", cursive',
};

function fail(message, code = 1) {
  console.error(`ERROR: ${message}`);
  process.exit(code);
}

function readJson(path) {
  try {
    return JSON.parse(readFileSync(path, "utf8"));
  } catch (error) {
    fail(`Could not read JSON from ${path}: ${error.message}`);
  }
}

function writeJson(path, value) {
  try {
    writeFileSync(path, `${JSON.stringify(value, null, 2)}\n`, "utf8");
  } catch (error) {
    fail(`Could not write JSON to ${path}: ${error.message}`);
  }
}

function finite(value) {
  return typeof value === "number" && Number.isFinite(value);
}

function number(value, fallback) {
  return finite(value) ? value : fallback;
}

function hash(text) {
  let value = 2166136261;
  for (const char of String(text)) {
    value ^= char.charCodeAt(0);
    value = Math.imul(value, 16777619);
  }
  return value >>> 0;
}

function commonElement(id, type, x, y, width, height, style = {}) {
  return {
    id,
    type,
    x,
    y,
    width,
    height,
    angle: number(style.angle, 0),
    strokeColor: style.strokeColor ?? PALETTE_TOKENS.text.light.body,
    backgroundColor: style.backgroundColor ?? "transparent",
    fillStyle: style.fillStyle ?? "solid",
    strokeWidth: number(style.strokeWidth, 2),
    strokeStyle: style.strokeStyle ?? "solid",
    roughness: number(style.roughness, 1),
    opacity: 100,
    groupIds: [],
    frameId: null,
    index: null,
    roundness: type === "rectangle" ? { type: 3 } : null,
    seed: hash(`${id}:seed`),
    version: 1,
    versionNonce: hash(`${id}:nonce`),
    isDeleted: false,
    boundElements: null,
    updated: 1,
    link: null,
    locked: false,
  };
}

function tone(name, theme = "light") {
  const palette = theme === "dark" ? DARK_PALETTE : PALETTE;
  return palette[name] ?? palette.primary;
}

function approxCharWidth(fontSize, fontFamily) {
  return fontSize * (fontFamily === 3 ? 0.61 : 0.54);
}

function wrapText(text, maxWidth, fontSize, fontFamily) {
  const limit = Math.max(4, Math.floor(maxWidth / approxCharWidth(fontSize, fontFamily)));
  return String(text)
    .split("\n")
    .flatMap((paragraph) => {
      const words = paragraph.trim().split(/\s+/).filter(Boolean);
      if (!words.length) return [""];
      const lines = [];
      let line = "";
      for (const word of words) {
        if (word.length > limit) {
          if (line) {
            lines.push(line);
            line = "";
          }
          const chunks = [];
          for (let i = 0; i < word.length; i += limit) chunks.push(word.slice(i, i + limit));
          lines.push(...chunks.slice(0, -1));
          line = chunks.at(-1);
          continue;
        }
        const candidate = line ? `${line} ${word}` : word;
        if (candidate.length <= limit) line = candidate;
        else {
          lines.push(line);
          line = word;
        }
      }
      if (line) lines.push(line);
      return lines;
    })
    .join("\n");
}

function textMetrics(text, fontSize, fontFamily, lineHeight = 1.25) {
  const lines = String(text).split("\n");
  return {
    width: Math.max(...lines.map((line) => line.length * approxCharWidth(fontSize, fontFamily)), 1),
    height: lines.length * fontSize * lineHeight,
    lines,
  };
}

function makeText({
  id,
  text,
  x,
  y,
  width,
  fontSize = 20,
  fontFamily = 5,
  color = PALETTE_TOKENS.text.light.body,
  textAlign = "left",
  verticalAlign = "top",
  containerId = null,
  code = false,
}) {
  const family = code ? 3 : fontFamily;
  const lineHeight = code ? 1.2 : 1.25;
  const metrics = textMetrics(text, fontSize, family, lineHeight);
  const elementWidth = number(width, Math.ceil(metrics.width));
  const element = commonElement(id, "text", x, y, elementWidth, Math.ceil(metrics.height), {
    strokeColor: color,
    strokeWidth: 1,
    roughness: 0,
  });
  return {
    ...element,
    text,
    fontSize,
    fontFamily: family,
    textAlign,
    verticalAlign,
    containerId,
    originalText: text,
    autoResize: true,
    lineHeight,
  };
}

function normalizePoint(point) {
  if (Array.isArray(point) && point.length >= 2 && finite(point[0]) && finite(point[1])) {
    return [point[0], point[1]];
  }
  if (point && finite(point.x) && finite(point.y)) return [point.x, point.y];
  throw new Error(`Invalid point: ${JSON.stringify(point)}`);
}

function anchor(shape, target) {
  const center = { x: shape.x + shape.width / 2, y: shape.y + shape.height / 2 };
  const other = { x: target.x + target.width / 2, y: target.y + target.height / 2 };
  const dx = other.x - center.x;
  const dy = other.y - center.y;
  if (Math.abs(dx / Math.max(shape.width, 1)) >= Math.abs(dy / Math.max(shape.height, 1))) {
    return { x: center.x + Math.sign(dx || 1) * shape.width / 2, y: center.y };
  }
  return { x: center.x, y: center.y + Math.sign(dy || 1) * shape.height / 2 };
}

function bindingFor(shape, point) {
  const fx = (point.x - shape.x) / Math.max(shape.width, 1);
  const fy = (point.y - shape.y) / Math.max(shape.height, 1);
  return {
    elementId: shape.id,
    focus: 0,
    gap: 8,
    fixedPoint: [Math.max(0, Math.min(1, fx)), Math.max(0, Math.min(1, fy))],
  };
}

function polylineMidpoint(points) {
  const segments = [];
  let total = 0;
  for (let index = 1; index < points.length; index += 1) {
    const start = points[index - 1];
    const end = points[index];
    const length = Math.hypot(end.x - start.x, end.y - start.y);
    segments.push({ start, end, length });
    total += length;
  }
  let remaining = total / 2;
  for (const segment of segments) {
    if (remaining <= segment.length) {
      const ratio = segment.length ? remaining / segment.length : 0;
      return {
        x: segment.start.x + (segment.end.x - segment.start.x) * ratio,
        y: segment.start.y + (segment.end.y - segment.start.y) * ratio,
      };
    }
    remaining -= segment.length;
  }
  return points.at(-1);
}

function addBound(element, id, type) {
  element.boundElements ??= [];
  if (!element.boundElements.some((entry) => entry.id === id)) {
    element.boundElements.push({ id, type });
  }
}

function compileScene(spec) {
  const errors = [];
  if (!spec || typeof spec !== "object" || Array.isArray(spec)) {
    fail("Scene specification must be a JSON object.");
  }
  const elements = [];
  const shapes = new Map();
  const nodes = new Map();
  const dark = spec.theme !== "light";
  const theme = dark ? "dark" : "light";
  const themeText = PALETTE_TOKENS.text[theme];
  const defaultRoughness = number(spec.roughness, 1);
  const defaultFont = 5;
  const titleColor = themeText.title;
  const bodyColor = themeText.body;

  const numericFields = [
    [spec, ["roughness", "titleX", "titleY"], "root"],
    ...((spec.sections ?? []).map((item, index) => [
      item,
      ["x", "y", "width", "height", "strokeWidth", "roughness", "fontSize"],
      `sections[${index}]`,
    ])),
    ...((spec.nodes ?? []).map((item, index) => [
      item,
      ["x", "y", "width", "height", "strokeWidth", "roughness", "fontSize", "padding"],
      `nodes[${index}]`,
    ])),
    ...((spec.edges ?? []).map((item, index) => [
      item,
      ["strokeWidth", "roughness", "fontSize", "labelDx", "labelDy"],
      `edges[${index}]`,
    ])),
    ...((spec.lines ?? []).map((item, index) => [
      item,
      ["strokeWidth", "roughness"],
      `lines[${index}]`,
    ])),
    ...((spec.texts ?? []).map((item, index) => [
      item,
      ["x", "y", "width", "fontSize"],
      `texts[${index}]`,
    ])),
  ];
  for (const [object, fields, context] of numericFields) {
    for (const field of fields) {
      if (object[field] !== undefined && !finite(object[field])) {
        errors.push(`${context}.${field} must be a finite number.`);
      }
    }
  }
  for (const [edgeIndex, edge] of (spec.edges ?? []).entries()) {
    for (const [pointIndex, point] of (edge.route ?? []).entries()) {
      const valid =
        (Array.isArray(point) && point.length >= 2 && finite(point[0]) && finite(point[1])) ||
        (point && finite(point.x) && finite(point.y));
      if (!valid) errors.push(`edges[${edgeIndex}].route[${pointIndex}] must contain two finite numbers.`);
    }
  }
  for (const [lineIndex, line] of (spec.lines ?? []).entries()) {
    for (const [pointIndex, point] of (line.points ?? []).entries()) {
      const valid =
        (Array.isArray(point) && point.length >= 2 && finite(point[0]) && finite(point[1])) ||
        (point && finite(point.x) && finite(point.y));
      if (!valid) errors.push(`lines[${lineIndex}].points[${pointIndex}] must contain two finite numbers.`);
    }
  }
  if (errors.length) fail(`Scene specification is invalid:\n- ${errors.join("\n- ")}`);

  if (spec.title) {
    elements.push(
      makeText({
        id: "scene-title",
        text: String(spec.title),
        x: number(spec.titleX, 60),
        y: number(spec.titleY, 40),
        fontSize: 32,
        fontFamily: defaultFont,
        color: titleColor,
      }),
    );
  }
  if (spec.subtitle) {
    elements.push(
      makeText({
        id: "scene-subtitle",
        text: String(spec.subtitle),
        x: number(spec.titleX, 60),
        y: number(spec.titleY, 40) + 48,
        fontSize: 18,
        fontFamily: defaultFont,
        color: themeText.subtitle,
      }),
    );
  }

  for (const section of spec.sections ?? []) {
    const id = String(section.id ?? "");
    if (!id) {
      errors.push("Every section needs an id.");
      continue;
    }
    const colors = tone(section.tone ?? "tertiary", dark ? "dark" : "light");
    const shape = commonElement(
      id,
      "rectangle",
      number(section.x, 0),
      number(section.y, 0),
      number(section.width, 480),
      number(section.height, 320),
      {
        strokeColor: section.strokeColor ?? colors.stroke,
        backgroundColor: section.backgroundColor ?? colors.fill,
        strokeWidth: number(section.strokeWidth, 1),
        strokeStyle: section.strokeStyle ?? "dashed",
        roughness: number(section.roughness, 0),
      },
    );
    shape.customData = { excalidrawSkill: { role: "section" } };
    elements.push(shape);
    shapes.set(id, shape);
    if (section.title) {
      elements.push(
        makeText({
          id: `${id}-title`,
          text: String(section.title),
          x: shape.x + 20,
          y: shape.y + 16,
          fontSize: number(section.fontSize, 20),
          fontFamily: defaultFont,
          color: section.titleColor ?? colors.stroke,
        }),
      );
    }
  }

  for (const node of spec.nodes ?? []) {
    const id = String(node.id ?? "");
    if (!id) {
      errors.push("Every node needs an id.");
      continue;
    }
    if (shapes.has(id)) {
      errors.push(`Duplicate shape id: ${id}`);
      continue;
    }
    const type = node.shape ?? "rectangle";
    if (!new Set(["rectangle", "ellipse", "diamond"]).has(type)) {
      errors.push(`Node ${id} has unsupported shape "${type}".`);
      continue;
    }
    const colors = tone(node.tone ?? "primary", dark ? "dark" : "light");
    const width = number(node.width, 200);
    const height = number(node.height, 96);
    const shape = commonElement(
      id,
      type,
      number(node.x, 0),
      number(node.y, 0),
      width,
      height,
      {
        strokeColor: node.strokeColor ?? colors.stroke,
        backgroundColor: node.backgroundColor ?? colors.fill,
        strokeWidth: number(node.strokeWidth, 2),
        strokeStyle: node.strokeStyle ?? "solid",
        roughness: number(node.roughness, defaultRoughness),
      },
    );
    if (type !== "rectangle") shape.roundness = null;
    elements.push(shape);
    shapes.set(id, shape);
    nodes.set(id, shape);

    if (node.text) {
      const fontSize = number(node.fontSize, node.code ? 16 : 20);
      const padding = number(node.padding, 18);
      const family = node.code ? 3 : defaultFont;
      const wrapped = wrapText(String(node.text), width - padding * 2, fontSize, family);
      const metrics = textMetrics(wrapped, fontSize, family, node.code ? 1.2 : 1.25);
      const label = makeText({
        id: `${id}-label`,
        text: wrapped,
        x: shape.x + (shape.width - Math.min(metrics.width, shape.width - padding * 2)) / 2,
        y: shape.y + (shape.height - metrics.height) / 2,
        width: Math.min(metrics.width, shape.width - padding * 2),
        fontSize,
        fontFamily: family,
        color: node.textColor ?? bodyColor,
        textAlign: "center",
        verticalAlign: "middle",
        containerId: id,
        code: Boolean(node.code),
      });
      addBound(shape, label.id, "text");
      elements.push(label);
    }
  }

  const edgeElements = [];
  const edgeLabels = [];
  for (const edge of spec.edges ?? []) {
    const id = String(edge.id ?? `${edge.from ?? "source"}-to-${edge.to ?? "target"}`);
    const source = nodes.get(edge.from);
    const target = nodes.get(edge.to);
    if (!source || !target) {
      errors.push(`Edge ${id} must connect existing nodes: ${edge.from} -> ${edge.to}.`);
      continue;
    }
    const start = anchor(source, target);
    const end = anchor(target, source);
    const absolutePoints = edge.route
      ? [start, ...edge.route.map((point) => {
          const [x, y] = normalizePoint(point);
          return { x, y };
        }), end]
      : [start, end];
    const points = absolutePoints.map((point) => [point.x - start.x, point.y - start.y]);
    const xs = points.map(([x]) => x);
    const ys = points.map(([, y]) => y);
    const arrow = {
      ...commonElement(
        id,
        "arrow",
        start.x,
        start.y,
        Math.max(...xs) - Math.min(...xs),
        Math.max(...ys) - Math.min(...ys),
        {
          strokeColor: edge.strokeColor ?? source.strokeColor,
          strokeWidth: number(edge.strokeWidth, 2),
          strokeStyle: edge.strokeStyle ?? "solid",
          roughness: number(edge.roughness, defaultRoughness),
        },
      ),
      points,
      lastCommittedPoint: null,
      startBinding: bindingFor(source, start),
      endBinding: bindingFor(target, end),
      startArrowhead: edge.startArrowhead ?? null,
      endArrowhead: edge.endArrowhead ?? "arrow",
      elbowed: false,
    };
    arrow.roundness = edge.curved ? { type: 2 } : null;
    addBound(source, id, "arrow");
    addBound(target, id, "arrow");
    edgeElements.push(arrow);

    if (edge.label) {
      const midpoint = polylineMidpoint(absolutePoints);
      const fontSize = number(edge.fontSize, 16);
      const metrics = textMetrics(String(edge.label), fontSize, defaultFont);
      const label = makeText({
        id: `${id}-label`,
        text: String(edge.label),
        x: midpoint.x - metrics.width / 2 + number(edge.labelDx, 0),
        y: midpoint.y + number(edge.labelDy, -32),
        fontSize,
        fontFamily: defaultFont,
        color: edge.labelColor ?? source.strokeColor,
      });
      edgeLabels.push(label);
    }
  }

  for (const line of spec.lines ?? []) {
    const id = String(line.id ?? `line-${edgeElements.length + 1}`);
    const absolute = (line.points ?? []).map(normalizePoint);
    if (absolute.length < 2) {
      errors.push(`Line ${id} needs at least two points.`);
      continue;
    }
    const [originX, originY] = absolute[0];
    const points = absolute.map(([x, y]) => [x - originX, y - originY]);
    const xs = points.map(([x]) => x);
    const ys = points.map(([, y]) => y);
    edgeElements.push({
      ...commonElement(
        id,
        line.arrow ? "arrow" : "line",
        originX,
        originY,
        Math.max(...xs) - Math.min(...xs),
        Math.max(...ys) - Math.min(...ys),
        {
          strokeColor: line.strokeColor ?? PALETTE_TOKENS.lines[theme].structural,
          strokeWidth: number(line.strokeWidth, 2),
          strokeStyle: line.strokeStyle ?? "solid",
          roughness: number(line.roughness, defaultRoughness),
        },
      ),
      points,
      lastCommittedPoint: null,
      startBinding: null,
      endBinding: null,
      startArrowhead: line.startArrowhead ?? null,
      endArrowhead: line.arrow ? (line.endArrowhead ?? "arrow") : null,
      elbowed: false,
    });
    edgeElements.at(-1).roundness = line.curved ? { type: 2 } : null;
  }

  elements.push(...edgeElements, ...edgeLabels);

  for (const item of spec.texts ?? []) {
    if (!item.id || !item.text) {
      errors.push("Every free text item needs id and text.");
      continue;
    }
    const fontSize = number(item.fontSize, item.code ? 16 : 18);
    const family = item.code ? 3 : defaultFont;
    const text = item.wrap === false
      ? String(item.text)
      : wrapText(String(item.text), number(item.width, 360), fontSize, family);
    elements.push(
      makeText({
        id: String(item.id),
        text,
        x: number(item.x, 0),
        y: number(item.y, 0),
        width: number(item.width, undefined),
        fontSize,
        fontFamily: family,
        color: item.color ?? bodyColor,
        textAlign: item.textAlign ?? "left",
        verticalAlign: item.verticalAlign ?? "top",
        code: Boolean(item.code),
      }),
    );
  }

  if (errors.length) fail(`Scene specification is invalid:\n- ${errors.join("\n- ")}`);

  return {
    type: "excalidraw",
    version: 2,
    source: "https://excalidraw.com",
    elements,
    appState: {
      viewBackgroundColor: spec.canvasBackground ?? PALETTE_TOKENS.canvas[theme],
      theme: dark ? "dark" : "light",
      gridSize: null,
    },
    files: {},
  };
}

function box(element) {
  if (LINE_TYPES.has(element.type) && Array.isArray(element.points)) {
    const xs = element.points.map((point) => element.x + Number(point[0]));
    const ys = element.points.map((point) => element.y + Number(point[1]));
    return {
      left: Math.min(...xs),
      top: Math.min(...ys),
      right: Math.max(...xs),
      bottom: Math.max(...ys),
    };
  }
  return {
    left: element.x,
    top: element.y,
    right: element.x + element.width,
    bottom: element.y + element.height,
  };
}

function intersects(a, b, inset = 0) {
  return (
    a.left < b.right - inset &&
    a.right > b.left + inset &&
    a.top < b.bottom - inset &&
    a.bottom > b.top + inset
  );
}

function pointInBox(point, target, padding = 0) {
  return (
    point.x > target.left + padding &&
    point.x < target.right - padding &&
    point.y > target.top + padding &&
    point.y < target.bottom - padding
  );
}

function segmentHitsBox(start, end, target) {
  const steps = Math.max(2, Math.ceil(Math.hypot(end.x - start.x, end.y - start.y) / 12));
  for (let i = 1; i < steps; i += 1) {
    const t = i / steps;
    if (
      pointInBox(
        { x: start.x + (end.x - start.x) * t, y: start.y + (end.y - start.y) * t },
        target,
        4,
      )
    ) {
      return true;
    }
  }
  return false;
}

function validateScene(scene) {
  const errors = [];
  const warnings = [];
  if (!scene || typeof scene !== "object" || Array.isArray(scene)) {
    return { errors: ["Root must be a JSON object."], warnings };
  }
  if (scene.type !== "excalidraw") errors.push(`Root type must be "excalidraw", got ${JSON.stringify(scene.type)}.`);
  if (scene.version !== 2) warnings.push(`Expected scene version 2, got ${JSON.stringify(scene.version)}.`);
  if (!Array.isArray(scene.elements)) errors.push("Root elements must be an array.");
  if (!scene.appState || typeof scene.appState !== "object") warnings.push("Root appState is missing.");
  if (!scene.files || typeof scene.files !== "object") warnings.push("Root files map is missing.");
  if (errors.length) return { errors, warnings };

  const live = scene.elements.filter((element) => !element?.isDeleted);
  const byId = new Map();
  for (const [index, element] of live.entries()) {
    const prefix = `elements[${index}]`;
    if (!element || typeof element !== "object") {
      errors.push(`${prefix} must be an object.`);
      continue;
    }
    if (!element.id || typeof element.id !== "string") errors.push(`${prefix} needs a string id.`);
    else if (byId.has(element.id)) errors.push(`Duplicate element id: ${element.id}.`);
    else byId.set(element.id, element);
    if (!SUPPORTED_TYPES.has(element.type)) warnings.push(`${element.id ?? prefix} uses unsupported preview type "${element.type}".`);
    if (finite(element.angle) && element.angle !== 0) {
      warnings.push(`${element.id ?? prefix} is rotated; the deterministic preview does not model rotation.`);
    }
    for (const key of ["x", "y", "width", "height"]) {
      if (!finite(element[key])) errors.push(`${element.id ?? prefix}.${key} must be a finite number.`);
    }
    if (finite(element.width) && element.width < 0) errors.push(`${element.id ?? prefix}.width must not be negative.`);
    if (finite(element.height) && element.height < 0) errors.push(`${element.id ?? prefix}.height must not be negative.`);
    if (LINE_TYPES.has(element.type)) {
      if (!Array.isArray(element.points) || element.points.length < 2) {
        errors.push(`${element.id ?? prefix} needs at least two points.`);
      } else {
        element.points.forEach((point, pointIndex) => {
          if (!Array.isArray(point) || point.length < 2 || !finite(point[0]) || !finite(point[1])) {
            errors.push(`${element.id ?? prefix}.points[${pointIndex}] must contain two finite numbers.`);
          }
        });
      }
    }
    if (element.type === "text") {
      if (typeof element.text !== "string" || !element.text.length) errors.push(`${element.id ?? prefix} has empty text.`);
      if (!finite(element.fontSize) || element.fontSize <= 0) errors.push(`${element.id ?? prefix} needs a positive fontSize.`);
      if (typeof element.text === "string" && finite(element.fontSize) && finite(element.width)) {
        const metrics = textMetrics(
          element.text,
          element.fontSize,
          element.fontFamily,
          number(element.lineHeight, 1.25),
        );
        if (metrics.width > element.width * 1.25) {
          warnings.push(`${element.id} text may clip horizontally (${Math.ceil(metrics.width)}px estimate in ${Math.ceil(element.width)}px box).`);
        }
        if (metrics.height > element.height * 1.2) {
          warnings.push(`${element.id} text may clip vertically (${Math.ceil(metrics.height)}px estimate in ${Math.ceil(element.height)}px box).`);
        }
      }
    }
  }

  for (const element of live) {
    if (!element?.id) continue;
    if (element.containerId) {
      const container = byId.get(element.containerId);
      if (!container) errors.push(`${element.id}.containerId references missing ${element.containerId}.`);
      else if (!(container.boundElements ?? []).some((entry) => entry.id === element.id && entry.type === "text")) {
        errors.push(`${element.id} is not reciprocally bound from container ${container.id}.`);
      }
    }
    for (const entry of element.boundElements ?? []) {
      const bound = byId.get(entry.id);
      if (!bound) {
        errors.push(`${element.id}.boundElements references missing ${entry.id}.`);
        continue;
      }
      if (entry.type === "text" && bound.containerId !== element.id) {
        errors.push(`${element.id} -> ${bound.id} text binding is not reciprocal.`);
      }
      if (
        entry.type === "arrow" &&
        bound.startBinding?.elementId !== element.id &&
        bound.endBinding?.elementId !== element.id
      ) {
        errors.push(`${element.id} -> ${bound.id} arrow binding is not reciprocal.`);
      }
    }
    for (const key of ["startBinding", "endBinding"]) {
      const binding = element[key];
      if (!binding) continue;
      const target = byId.get(binding.elementId);
      if (!target) {
        errors.push(`${element.id}.${key} references missing ${binding.elementId}.`);
      } else if (target.customData?.excalidrawSkill?.role === "section") {
        errors.push(`${element.id}.${key} must bind to a node, not section ${target.id}.`);
      } else if (!(target.boundElements ?? []).some((entry) => entry.id === element.id && entry.type === "arrow")) {
        errors.push(`${element.id}.${key} is not reciprocally bound from ${target.id}.`);
      }
    }
    if (element.type === "image" && element.fileId && !scene.files?.[element.fileId]) {
      errors.push(`${element.id} references missing image file ${element.fileId}.`);
    }
    if (element.type === "image" && !element.fileId) {
      errors.push(`${element.id} is an image without fileId.`);
    }
  }

  const primaryShapes = live.filter(
    (element) =>
      new Set(["diamond", "ellipse", "rectangle"]).has(element.type) &&
      !element.containerId &&
      element.customData?.excalidrawSkill?.role !== "section",
  );
  for (let i = 0; i < primaryShapes.length; i += 1) {
    for (let j = i + 1; j < primaryShapes.length; j += 1) {
      const a = primaryShapes[i];
      const b = primaryShapes[j];
      if (intersects(box(a), box(b), 8)) warnings.push(`${a.id} overlaps ${b.id}.`);
    }
  }

  for (const edge of live.filter((element) => LINE_TYPES.has(element.type) && Array.isArray(element.points))) {
    const ignored = new Set([edge.startBinding?.elementId, edge.endBinding?.elementId].filter(Boolean));
    const absolute = edge.points.map(([x, y]) => ({ x: edge.x + x, y: edge.y + y }));
    for (const shape of primaryShapes) {
      if (ignored.has(shape.id)) continue;
      for (let i = 1; i < absolute.length; i += 1) {
        if (segmentHitsBox(absolute[i - 1], absolute[i], box(shape))) {
          warnings.push(`${edge.id} crosses ${shape.id}; move the shape or route the edge.`);
          break;
        }
      }
    }
  }

  if (live.length) {
    const boxes = live
      .filter((element) => finite(element.x) && finite(element.y) && finite(element.width) && finite(element.height))
      .map(box);
    const bounds = {
      left: Math.min(...boxes.map((item) => item.left)),
      top: Math.min(...boxes.map((item) => item.top)),
      right: Math.max(...boxes.map((item) => item.right)),
      bottom: Math.max(...boxes.map((item) => item.bottom)),
    };
    const width = bounds.right - bounds.left;
    const height = bounds.bottom - bounds.top;
    if (width > 3600 || height > 2600) {
      warnings.push(`Canvas is ${Math.ceil(width)}x${Math.ceil(height)}px; prefer an overview plus focused diagrams.`);
    }
    const textCount = live.filter((element) => element.type === "text").length;
    const boxedTextCount = live.filter((element) => element.type === "text" && element.containerId).length;
    if (textCount >= 6 && boxedTextCount / textCount > 0.5) {
      warnings.push(`${Math.round((boxedTextCount / textCount) * 100)}% of text is boxed; remove containers that carry no meaning.`);
    }
  }

  return { errors, warnings };
}

function escapeXml(value) {
  return String(value)
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&apos;");
}

function dashArray(style) {
  if (style === "dashed") return "10 8";
  if (style === "dotted") return "2 7";
  return "none";
}

function renderText(element) {
  const fontSize = number(element.fontSize, 20);
  const lineHeight = number(element.lineHeight, 1.25) * fontSize;
  const lines = String(element.text ?? "").split("\n");
  const anchor = element.textAlign === "center" ? "middle" : element.textAlign === "right" ? "end" : "start";
  const x =
    element.textAlign === "center"
      ? element.x + element.width / 2
      : element.textAlign === "right"
        ? element.x + element.width
        : element.x;
  const y = element.y + fontSize;
  const family = FONT_FAMILY[element.fontFamily] ?? FONT_FAMILY[5];
  const tspans = lines
    .map((line, index) => `<tspan x="${x}" dy="${index ? lineHeight : 0}">${escapeXml(line)}</tspan>`)
    .join("");
  return `<text x="${x}" y="${y}" fill="${escapeXml(element.strokeColor ?? PALETTE_TOKENS.text.light.body)}" font-family="${escapeXml(family)}" font-size="${fontSize}" text-anchor="${anchor}" dominant-baseline="alphabetic">${tspans}</text>`;
}

function renderShape(element) {
  const stroke = escapeXml(element.strokeColor ?? PALETTE_TOKENS.text.light.body);
  const fill = escapeXml(element.backgroundColor ?? "transparent");
  const strokeWidth = number(element.strokeWidth, 2);
  const dash = dashArray(element.strokeStyle);
  const style = `fill="${fill}" stroke="${stroke}" stroke-width="${strokeWidth}" stroke-dasharray="${dash}"`;
  if (element.type === "ellipse") {
    return `<ellipse cx="${element.x + element.width / 2}" cy="${element.y + element.height / 2}" rx="${element.width / 2}" ry="${element.height / 2}" ${style}/>`;
  }
  if (element.type === "diamond") {
    const points = [
      [element.x + element.width / 2, element.y],
      [element.x + element.width, element.y + element.height / 2],
      [element.x + element.width / 2, element.y + element.height],
      [element.x, element.y + element.height / 2],
    ]
      .map((point) => point.join(","))
      .join(" ");
    return `<polygon points="${points}" ${style}/>`;
  }
  const radius = element.roundness ? Math.min(16, element.width / 8, element.height / 8) : 0;
  return `<rect x="${element.x}" y="${element.y}" width="${element.width}" height="${element.height}" rx="${radius}" ${style}/>`;
}

function renderLine(element) {
  const absolute = element.points.map(([x, y]) => [element.x + x, element.y + y]);
  const markerStart = element.startArrowhead ? ' marker-start="url(#arrow-start)"' : "";
  const markerEnd = element.endArrowhead ? ' marker-end="url(#arrow-end)"' : "";
  const attributes = `fill="none" stroke="${escapeXml(element.strokeColor ?? PALETTE_TOKENS.lines.light.structural)}" stroke-width="${number(element.strokeWidth, 2)}" stroke-dasharray="${dashArray(element.strokeStyle)}" stroke-linecap="round" stroke-linejoin="round"${markerStart}${markerEnd}`;
  if (element.roundness && absolute.length > 2) {
    let path = `M ${absolute[0][0]} ${absolute[0][1]}`;
    for (let index = 1; index < absolute.length - 1; index += 1) {
      const point = absolute[index];
      const next = absolute[index + 1];
      const midpoint = [(point[0] + next[0]) / 2, (point[1] + next[1]) / 2];
      path += ` Q ${point[0]} ${point[1]} ${midpoint[0]} ${midpoint[1]}`;
    }
    const last = absolute.at(-1);
    path += ` T ${last[0]} ${last[1]}`;
    return `<path d="${path}" ${attributes}/>`;
  }
  const points = absolute.map((point) => point.join(",")).join(" ");
  return `<polyline points="${points}" ${attributes}/>`;
}

function renderImage(element, files) {
  const dataUrl = files?.[element.fileId]?.dataURL;
  if (!dataUrl) return "";
  return `<image x="${element.x}" y="${element.y}" width="${element.width}" height="${element.height}" href="${escapeXml(dataUrl)}" preserveAspectRatio="xMidYMid meet"/>`;
}

function renderSvg(scene, padding = 48) {
  const live = scene.elements.filter((element) => !element?.isDeleted);
  if (!live.length) fail("Cannot preview an empty scene.");
  const boxes = live
    .filter((element) => finite(element.x) && finite(element.y) && finite(element.width) && finite(element.height))
    .map(box);
  const left = Math.min(...boxes.map((item) => item.left)) - padding;
  const top = Math.min(...boxes.map((item) => item.top)) - padding;
  const right = Math.max(...boxes.map((item) => item.right)) + padding;
  const bottom = Math.max(...boxes.map((item) => item.bottom)) + padding;
  const layoutWidth = Math.max(1, right - left);
  const layoutHeight = Math.max(1, bottom - top);
  const scale = Math.min(1, 1800 / layoutWidth, 1200 / layoutHeight);
  const width = Math.max(1, Math.min(1800, Math.ceil(layoutWidth * scale)));
  const height = Math.max(1, Math.min(1200, Math.ceil(layoutHeight * scale)));
  const background = scene.appState?.viewBackgroundColor ?? PALETTE_TOKENS.canvas.light;
  const body = live
    .map((element) => {
      if (element.type === "text") return renderText(element);
      if (SHAPE_TYPES.has(element.type)) return renderShape(element);
      if (LINE_TYPES.has(element.type) && Array.isArray(element.points)) return renderLine(element);
      if (element.type === "image") return renderImage(element, scene.files);
      return "";
    })
    .join("\n");
  return {
    width,
    height,
    svg: `<svg xmlns="http://www.w3.org/2000/svg" width="${width}" height="${height}" viewBox="${left} ${top} ${layoutWidth} ${layoutHeight}">
<defs>
  <marker id="arrow-end" markerWidth="10" markerHeight="10" refX="8" refY="3" orient="auto" markerUnits="strokeWidth"><path d="M0,0 L0,6 L9,3 z" fill="context-stroke"/></marker>
  <marker id="arrow-start" markerWidth="10" markerHeight="10" refX="1" refY="3" orient="auto-start-reverse" markerUnits="strokeWidth"><path d="M9,0 L9,6 L0,3 z" fill="context-stroke"/></marker>
</defs>
<rect x="${left}" y="${top}" width="${layoutWidth}" height="${layoutHeight}" fill="${escapeXml(background)}"/>
${body}
</svg>
`,
  };
}

function reportValidation(path, result) {
  for (const warning of result.warnings) console.warn(`WARN: ${warning}`);
  for (const error of result.errors) console.error(`ERROR: ${error}`);
  if (!result.errors.length) {
    console.log(
      `STRUCTURALLY VALID: ${path} (${result.warnings.length} warning${result.warnings.length === 1 ? "" : "s"})`,
    );
  }
}

function outputPath(input, suffix) {
  const filename = basename(input);
  const stem = filename.endsWith(".scene.json")
    ? filename.slice(0, -".scene.json".length)
    : basename(input, extname(input));
  return resolve(dirname(input), `${stem}${suffix}`);
}

function commandPath(command) {
  try {
    const locator = process.platform === "win32" ? "where.exe" : "which";
    return execFileSync(locator, [command], { encoding: "utf8" })
      .trim()
      .split(/\r?\n/)[0];
  } catch {
    return null;
  }
}

function browserCandidates(platform = process.platform, env = process.env) {
  const explicit = env.EXCALIDRAW_BROWSER_PATH ? [env.EXCALIDRAW_BROWSER_PATH] : [];
  if (platform === "win32") {
    const local = env.LOCALAPPDATA
      ? [
          win32Path.join(env.LOCALAPPDATA, "Google", "Chrome", "Application", "chrome.exe"),
          win32Path.join(env.LOCALAPPDATA, "Microsoft", "Edge", "Application", "msedge.exe"),
          win32Path.join(env.LOCALAPPDATA, "Chromium", "Application", "chrome.exe"),
        ]
      : [];
    const programRoots = [
      env.ProgramFiles ?? "C:\\Program Files",
      env["ProgramFiles(x86)"] ?? "C:\\Program Files (x86)",
    ];
    const installed = programRoots.flatMap((root) => [
      win32Path.join(root, "Google", "Chrome", "Application", "chrome.exe"),
      win32Path.join(root, "Microsoft", "Edge", "Application", "msedge.exe"),
      win32Path.join(root, "Chromium", "Application", "chrome.exe"),
    ]);
    return [
      ...explicit,
      ...local,
      ...installed,
      "chrome.exe",
      "chrome",
      "msedge.exe",
      "msedge",
      "chromium.exe",
      "chromium",
    ];
  }
  if (platform === "darwin") {
    return [
      ...explicit,
      "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
      "/Applications/Microsoft Edge.app/Contents/MacOS/Microsoft Edge",
      "/Applications/Chromium.app/Contents/MacOS/Chromium",
    ];
  }
  return [
    ...explicit,
    "google-chrome",
    "google-chrome-stable",
    "chromium",
    "chromium-browser",
    "microsoft-edge",
  ];
}

function findBrowser({
  platform = process.platform,
  env = process.env,
  fileExists = existsSync,
  locate = commandPath,
} = {}) {
  const candidates = browserCandidates(platform, env);
  for (const candidate of candidates) {
    if (fileExists(candidate)) return candidate;
    const absolute = platform === "win32" ? win32Path.isAbsolute(candidate) : isAbsolute(candidate);
    if (absolute) continue;
    const located = locate(candidate);
    if (located) return located;
  }
  return null;
}

function pngFromSvg(svgPath, pngPath, dimensions, options = {}) {
  const browser = options.browser ?? findBrowser(options);
  if (!browser) return { ok: false, reason: "Chrome, Chromium, or Edge was not found." };
  const width = Math.max(1, Math.ceil(dimensions.width));
  const height = Math.max(1, Math.ceil(dimensions.height));
  const spawn = options.spawn ?? spawnSync;
  const fileExists = options.fileExists ?? existsSync;
  const result = spawn(
    browser,
    [
      "--headless=new",
      "--disable-gpu",
      "--hide-scrollbars",
      "--force-device-scale-factor=1",
      `--window-size=${width},${height}`,
      `--screenshot=${resolve(pngPath)}`,
      pathToFileURL(resolve(svgPath)).href,
    ],
    { encoding: "utf8" },
  );
  if (result.status !== 0 || !fileExists(pngPath)) {
    return {
      ok: false,
      reason: (result.stderr || result.stdout || `browser exited ${result.status}`).trim(),
    };
  }
  return { ok: true, width, height };
}

function usage() {
  console.log(`Usage:
  node scripts/excalidraw.mjs build <scene.json> [output.excalidraw]
  node scripts/excalidraw.mjs validate <file.excalidraw>
  node scripts/excalidraw.mjs preview <file.excalidraw> [output.svg]
  node scripts/excalidraw.mjs check <file.excalidraw> [layout-preview.png]

Status vocabulary:
  STRUCTURALLY VALID  JSON, numbers, references, and reciprocal bindings passed.
  LAYOUT PREVIEWED    The dependency-free approximation rendered; this is not native verification.
  VISUALLY APPROVED   A human or vision-capable agent inspected the native pixels.
`);
}

function main(args = process.argv.slice(2)) {
  const [command, inputArg, outputArg] = args;
  if (!command || command === "--help" || command === "-h") {
    usage();
    process.exit(0);
  }
  if (!inputArg) fail(`${command} needs an input path.`);
  const input = resolve(inputArg);

  if (command === "build") {
    const scene = compileScene(readJson(input));
    const output = resolve(outputArg ?? outputPath(input, ".excalidraw"));
    const result = validateScene(scene);
    if (result.errors.length) {
      reportValidation(output, result);
      process.exit(1);
    }
    writeJson(output, scene);
    reportValidation(output, result);
    console.log(`BUILT: ${output}`);
    process.exit(0);
  }

  const scene = readJson(input);
  const validation = validateScene(scene);
  reportValidation(input, validation);
  if (validation.errors.length) process.exit(1);
  if (command === "validate") process.exit(0);

  const preview = renderSvg(scene);
  const svgPath =
    command === "preview"
      ? resolve(outputArg ?? outputPath(input, ".svg"))
      : outputPath(input, ".layout.svg");
  writeFileSync(svgPath, preview.svg, "utf8");
  console.log(`LAYOUT PREVIEW SVG: ${svgPath} (${Math.ceil(preview.width)}x${Math.ceil(preview.height)})`);
  if (command === "preview") process.exit(0);

  if (command === "check") {
    const layoutPngPath = resolve(outputArg ?? outputPath(input, ".layout.png"));
    const layoutPng = pngFromSvg(svgPath, layoutPngPath, preview);
    if (layoutPng.ok) {
      console.warn(`LAYOUT PREVIEW PNG: ${layoutPngPath} (${layoutPng.width}x${layoutPng.height})`);
    } else {
      console.warn(`Layout PNG unavailable: ${layoutPng.reason}`);
    }
    console.warn("NATIVE VISUALLY UNVERIFIED: import the .excalidraw file into an official Excalidraw surface and inspect those pixels.");
    process.exit(2);
  }

  fail(`Unknown command "${command}". Run with --help.`);
}

const invokedPath = process.argv[1] ? resolve(process.argv[1]) : null;
const modulePath = fileURLToPath(import.meta.url);
let invokedDirectly = invokedPath === modulePath;
if (invokedPath && !invokedDirectly) {
  try {
    invokedDirectly = realpathSync.native(invokedPath) === realpathSync.native(modulePath);
  } catch {
    // Fall back to the resolved path comparison when either path cannot be canonicalized.
  }
}
if (invokedDirectly) main();

export { browserCandidates, findBrowser, pngFromSvg };
