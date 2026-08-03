#!/usr/bin/env node

import { readFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";

class ValidationError extends Error {}

function fail(message) {
  throw new ValidationError(message);
}

function parseStartTag(token) {
  const selfClosing = /\/\s*>$/.test(token);
  const end = token.length - (selfClosing ? 2 : 1);
  const body = token.slice(1, end);
  const nameMatch = body.match(/^([A-Za-z_][\w:.-]*)/);
  if (!nameMatch) fail(`invalid start tag: ${token.slice(0, 60)}`);

  const name = nameMatch[1];
  const attrs = {};
  let cursor = name.length;
  while (cursor < body.length) {
    while (/\s/.test(body[cursor] ?? "")) cursor += 1;
    if (cursor >= body.length) break;

    const attrMatch = body.slice(cursor).match(/^([A-Za-z_][\w:.-]*)/);
    if (!attrMatch) fail(`invalid attribute in <${name}>`);
    const attrName = attrMatch[1];
    if (Object.hasOwn(attrs, attrName)) fail(`duplicate attribute ${attrName} in <${name}>`);
    cursor += attrName.length;
    while (/\s/.test(body[cursor] ?? "")) cursor += 1;
    if (body[cursor] !== "=") fail(`attribute ${attrName} in <${name}> has no value`);
    cursor += 1;
    while (/\s/.test(body[cursor] ?? "")) cursor += 1;

    const quote = body[cursor];
    if (quote !== '"' && quote !== "'") fail(`attribute ${attrName} in <${name}> is not quoted`);
    cursor += 1;
    const valueStart = cursor;
    while (cursor < body.length && body[cursor] !== quote) cursor += 1;
    if (cursor >= body.length) fail(`attribute ${attrName} in <${name}> is not closed`);
    const value = body.slice(valueStart, cursor);
    if (value.includes("<")) fail(`attribute ${attrName} in <${name}> contains an unescaped <`);
    if (/&(?!(?:amp|lt|gt|quot|apos|#\d+|#x[0-9A-Fa-f]+);)/.test(value)) {
      fail(`attribute ${attrName} in <${name}> contains an unescaped or invalid & entity`);
    }
    attrs[attrName] = value;
    cursor += 1;
  }

  return { name, attrs, children: [], selfClosing };
}

function findTagEnd(xml, start) {
  let quote = null;
  for (let i = start + 1; i < xml.length; i += 1) {
    const char = xml[i];
    if (quote) {
      if (char === quote) quote = null;
    } else if (char === '"' || char === "'") {
      quote = char;
    } else if (char === ">") {
      return i;
    }
  }
  fail("unterminated XML tag");
}

function parseXml(xml) {
  const document = { name: "#document", attrs: {}, children: [] };
  const stack = [document];
  let cursor = 0;

  while (cursor < xml.length) {
    const open = xml.indexOf("<", cursor);
    if (open === -1) {
      if (xml.slice(cursor).trim()) fail("text content is not supported; use uncompressed XML elements");
      break;
    }
    if (xml.slice(cursor, open).trim()) fail("text content is not supported; use uncompressed XML elements");

    if (xml.startsWith("<!--", open)) fail("XML comments are not allowed");
    if (xml.startsWith("<![CDATA[", open)) fail("CDATA is not allowed");
    if (/^<!DOCTYPE\b/i.test(xml.slice(open))) fail("DOCTYPE is not allowed");
    if (xml.startsWith("<?", open)) {
      const close = xml.indexOf("?>", open + 2);
      if (close === -1) fail("unterminated XML declaration");
      cursor = close + 2;
      continue;
    }

    const close = findTagEnd(xml, open);
    const token = xml.slice(open, close + 1);
    if (token.startsWith("</")) {
      const match = token.match(/^<\/\s*([A-Za-z_][\w:.-]*)\s*>$/);
      if (!match) fail(`invalid closing tag: ${token}`);
      const node = stack.pop();
      if (stack.length === 0 || node.name !== match[1]) {
        fail(`closing tag </${match[1]}> does not match <${node?.name ?? "none"}>`);
      }
    } else if (token.startsWith("<!")) {
      fail(`unsupported XML declaration: ${token.slice(0, 40)}`);
    } else {
      const node = parseStartTag(token);
      stack.at(-1).children.push(node);
      if (!node.selfClosing) stack.push(node);
    }
    cursor = close + 1;
  }

  if (stack.length !== 1) fail(`unclosed tag <${stack.at(-1).name}>`);
  if (document.children.length !== 1) fail("document must have exactly one root element");
  return document.children[0];
}

function directChildren(node, name) {
  return node.children.filter((child) => child.name === name);
}

function requireOnlyChildren(node, allowed, label) {
  const unexpected = node.children.find((child) => !allowed.includes(child.name));
  if (unexpected) fail(`${label}: unsupported child <${unexpected.name}>`);
}

function finiteNumber(value) {
  return value !== undefined && value.trim() !== "" && Number.isFinite(Number(value));
}

function descendants(node, name) {
  const found = [];
  for (const child of node.children) {
    if (child.name === name) found.push(child);
    found.push(...descendants(child, name));
  }
  return found;
}

function validateGeometry(geometry, label) {
  if (geometry.attrs.as !== "geometry") fail(`${label}: mxGeometry needs as=geometry`);
  for (const key of ["x", "y", "width", "height"]) {
    if (geometry.attrs[key] !== undefined && !finiteNumber(geometry.attrs[key])) {
      fail(`${label}: mxGeometry ${key} must be numeric`);
    }
  }
  for (const point of descendants(geometry, "mxPoint")) {
    if (!finiteNumber(point.attrs.x) || !finiteNumber(point.attrs.y)) {
      fail(`${label}: every mxPoint needs numeric x and y`);
    }
  }
}

// draw.io wraps a cell in <object>/<UserObject> when it carries custom properties;
// the wrapper owns the id and holds exactly one <mxCell> child.
const CELL_WRAPPERS = ["object", "UserObject"];

function collectCells(rootNode, label) {
  const entries = [];
  for (const child of rootNode.children) {
    if (child.name === "mxCell") {
      entries.push({ id: child.attrs.id, cell: child, owner: "mxCell" });
    } else if (CELL_WRAPPERS.includes(child.name)) {
      const inner = directChildren(child, "mxCell");
      if (inner.length !== 1) fail(`${label}: root: <${child.name}> needs exactly one mxCell child`);
      entries.push({ id: child.attrs.id, cell: inner[0], owner: child.name });
    } else {
      fail(`${label}: root: unsupported child <${child.name}>`);
    }
  }
  return entries;
}

function validateModel(model, label) {
  requireOnlyChildren(model, ["root"], `${label}: mxGraphModel`);
  const roots = directChildren(model, "root");
  if (roots.length !== 1) fail(`${label}: mxGraphModel must contain exactly one root`);
  const byId = new Map();

  for (const { id, cell, owner } of collectCells(roots[0], label)) {
    if (!id) fail(`${label}: every ${owner === "mxCell" ? "mxCell" : `<${owner}>`} needs an id`);
    if (byId.has(id)) fail(`${label}: duplicate mxCell id ${id}`);
    byId.set(id, cell);
  }

  if (!byId.has("0")) fail(`${label}: missing root cell id 0`);
  if (!byId.has("1")) fail(`${label}: missing default layer cell id 1`);
  if (byId.get("0").attrs.parent !== undefined) fail(`${label}: root cell id 0 must not have a parent`);
  if (byId.get("1").attrs.parent !== "0") fail(`${label}: default layer cell id 1 must have parent 0`);

  for (const [id, cell] of byId) {
    const { parent, source, target, vertex, edge } = cell.attrs;
    if (parent !== undefined && !byId.has(parent)) fail(`${label}: cell ${id} has unknown parent ${parent}`);
    if (vertex === "1" && edge === "1") fail(`${label}: cell ${id} cannot be both vertex and edge`);

    const geometry = directChildren(cell, "mxGeometry");
    if (vertex === "1") {
      if (!parent) fail(`${label}: vertex ${id} needs a parent`);
      if (geometry.length !== 1) fail(`${label}: vertex ${id} needs exactly one mxGeometry child`);
      validateGeometry(geometry[0], `${label}: vertex ${id}`);
      const attrs = geometry[0].attrs;
      if (attrs.relative !== "1") {
        for (const key of ["x", "y", "width", "height"]) {
          if (!finiteNumber(attrs[key])) fail(`${label}: vertex ${id} geometry needs numeric ${key}`);
        }
        if (Number(attrs.width) <= 0 || Number(attrs.height) <= 0) {
          fail(`${label}: vertex ${id} width and height must be positive`);
        }
      }
    }

    if (edge === "1") {
      if (!parent) fail(`${label}: edge ${id} needs a parent`);
      if (!source || !byId.has(source)) fail(`${label}: edge ${id} has missing or unknown source`);
      if (!target || !byId.has(target)) fail(`${label}: edge ${id} has missing or unknown target`);
      if (geometry.length !== 1 || geometry[0].attrs.relative !== "1") {
        fail(`${label}: edge ${id} needs exactly one mxGeometry with relative=1`);
      }
      validateGeometry(geometry[0], `${label}: edge ${id}`);
    }
  }

  return byId.size;
}

export function validateDocument(xml) {
  const root = parseXml(xml.replace(/^\uFEFF/, ""));
  if (root.name === "mxGraphModel") {
    return { pages: 1, cells: validateModel(root, "page 1") };
  }

  if (root.name !== "mxfile") fail("root element must be mxfile or mxGraphModel");
  if (root.attrs.compressed !== undefined && root.attrs.compressed !== "false") {
    fail("mxfile must be uncompressed (compressed=false)");
  }
  requireOnlyChildren(root, ["diagram"], "mxfile");
  const pages = directChildren(root, "diagram");
  if (pages.length === 0) fail("mxfile must contain at least one diagram page");
  const pageIds = new Set();
  let cells = 0;
  pages.forEach((page, index) => {
    const pageId = page.attrs.id;
    if (!pageId) fail(`page ${index + 1}: diagram needs an id`);
    if (pageIds.has(pageId)) fail(`duplicate diagram id ${pageId}`);
    pageIds.add(pageId);
    requireOnlyChildren(page, ["mxGraphModel"], `page ${index + 1}: diagram`);
    const models = directChildren(page, "mxGraphModel");
    if (models.length !== 1) fail(`page ${index + 1}: diagram must contain exactly one mxGraphModel`);
    cells += validateModel(models[0], `page ${index + 1}`);
  });
  return { pages: pages.length, cells };
}

async function main(args) {
  if (args.length === 0) {
    console.error("Usage: validate-drawio.mjs <file.drawio> [more.drawio ...]");
    process.exitCode = 2;
    return;
  }

  let failed = false;
  for (const file of args) {
    try {
      const result = validateDocument(await readFile(file, "utf8"));
      console.log(`PASS ${file}: ${result.pages} page(s), ${result.cells} cell(s)`);
    } catch (error) {
      failed = true;
      console.error(`FAIL ${file}: ${error.message}`);
    }
  }
  if (failed) process.exitCode = 1;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  await main(process.argv.slice(2));
}
