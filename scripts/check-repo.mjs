#!/usr/bin/env node

import fs from "node:fs";
import path from "node:path";
import process from "node:process";
import { fileURLToPath } from "node:url";

const repo = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const failures = [];

function fail(message) {
  failures.push(message);
}

function read(relativePath) {
  return fs.readFileSync(path.join(repo, relativePath), "utf8").replace(/\r\n/g, "\n");
}

function validateSkill(skillDir) {
  const file = path.join(skillDir, "SKILL.md");
  const text = fs.readFileSync(file, "utf8").replace(/\r\n/g, "\n");
  const match = text.match(/^---\n([\s\S]*?)\n---(?:\n|$)/);
  const label = path.relative(repo, file).replaceAll("\\", "/");
  if (!match) {
    fail(`${label}: missing closed YAML frontmatter`);
    return;
  }

  const frontmatter = match[1];
  const name = frontmatter.match(/^name:\s*([a-z0-9-]+)\s*$/m)?.[1];
  if (!name) fail(`${label}: missing or invalid name`);
  if (name && name !== path.basename(skillDir)) {
    fail(`${label}: name ${name} does not match folder ${path.basename(skillDir)}`);
  }

  const lines = frontmatter.split("\n");
  const descriptionIndex = lines.findIndex((line) => line.startsWith("description:"));
  if (descriptionIndex < 0) {
    fail(`${label}: missing description`);
  } else {
    const value = lines[descriptionIndex].slice("description:".length).trim();
    if (/^[>|][+-]?$/.test(value)) {
      const body = lines.slice(descriptionIndex + 1).filter((line) => /^\s+\S/.test(line));
      if (body.length === 0) fail(`${label}: empty block description`);
    } else if (!value) {
      fail(`${label}: empty description`);
    } else if (!/^['"]/.test(value) && value.includes(": ")) {
      fail(`${label}: plain description contains an unquoted colon-space`);
    }
  }

  if (!/^disable-model-invocation: true$/m.test(frontmatter)) {
    fail(`${label}: missing disable-model-invocation: true (every skill here is explicit-invocation only; canary 2026-08-20 proved typed /name and picker visibility survive the flag)`);
  }

  // Cross-skill path references (the shared-executable convention) must point
  // at files that exist, or a selective install breaks silently.
  for (const ref of text.matchAll(/skills\/([a-z0-9-]+\/[A-Za-z0-9_./-]+\.(?:sh|mjs|js|md|yaml))/g)) {
    // Deployment candidates like ~/skills/skills/<name>/... double the prefix.
    const rel = ref[1].startsWith("skills/") ? ref[1].slice("skills/".length) : ref[1];
    if (!fs.existsSync(path.join(repo, "skills", rel))) {
      fail(`${label}: references skills/${rel} which does not exist in this repository`);
    }
  }
}

const skillsRoot = path.join(repo, "skills");
const skillDirs = fs.readdirSync(skillsRoot, { withFileTypes: true })
  .filter((entry) => entry.isDirectory() && fs.existsSync(path.join(skillsRoot, entry.name, "SKILL.md")))
  .map((entry) => path.join(skillsRoot, entry.name))
  .sort();

for (const skillDir of skillDirs) validateSkill(skillDir);

// Subagent definitions share the cross-skill path rule.
const agentsDir = path.join(repo, "agents");
if (fs.existsSync(agentsDir)) {
  for (const entry of fs.readdirSync(agentsDir).filter((f) => f.endsWith(".md"))) {
    const text = read(path.join("agents", entry));
    for (const ref of text.matchAll(/skills\/([a-z0-9-]+\/[A-Za-z0-9_./-]+\.(?:sh|mjs|js|md|yaml))/g)) {
      const rel = ref[1].startsWith("skills/") ? ref[1].slice("skills/".length) : ref[1];
      if (!fs.existsSync(path.join(repo, "skills", rel))) {
        fail(`agents/${entry}: references skills/${rel} which does not exist in this repository`);
      }
    }
  }
}

for (const extra of process.argv.slice(2)) {
  const skillDir = path.resolve(extra);
  if (!fs.existsSync(path.join(skillDir, "SKILL.md"))) fail(`${extra}: no SKILL.md`);
  else validateSkill(skillDir);
}

const claudeManifest = JSON.parse(read(".claude-plugin/plugin.json"));
const codexManifest = JSON.parse(read(".codex-plugin/plugin.json"));
if (claudeManifest.version !== codexManifest.version) {
  fail(`manifest versions differ: Claude ${claudeManifest.version}, Codex ${codexManifest.version}`);
}
if (Object.hasOwn(claudeManifest, "skills")) {
  fail(".claude-plugin/plugin.json must not carry a skills allowlist");
}

const markerNames = skillDirs
  .filter((dir) => fs.existsSync(path.join(dir, "agents", "openai.yaml")))
  .map((dir) => path.basename(dir));
const manifestNames = [...codexManifest.skills]
  .map((entry) => entry.replace(/^\.\/skills\//, ""))
  .sort();
if (JSON.stringify(markerNames) !== JSON.stringify(manifestNames)) {
  fail(`Codex manifest skills differ from openai.yaml markers: markers=${markerNames.join(",")} manifest=${manifestNames.join(",")}`);
}
for (const name of markerNames) {
  const metadata = read(`skills/${name}/agents/openai.yaml`);
  if (!/^\s*allow_implicit_invocation:\s*false\s*$/m.test(metadata)) {
    fail(`skills/${name}/agents/openai.yaml must disable implicit invocation`);
  }
}

const readme = read("README.md");
const linkedSkills = [...readme.matchAll(/\]\(skills\/([a-z0-9-]+)\)/g)].map((match) => match[1]);
const uniqueLinkedSkills = [...new Set(linkedSkills)].sort();
const allSkillNames = skillDirs.map((dir) => path.basename(dir));
if (JSON.stringify(uniqueLinkedSkills) !== JSON.stringify(allSkillNames)) {
  fail(`README skill links differ from folders: README=${uniqueLinkedSkills.join(",")} folders=${allSkillNames.join(",")}`);
}
if (linkedSkills.length !== uniqueLinkedSkills.length) {
  fail("README.md lists at least one skill more than once");
}

const sharedSection = readme.match(/### Claude Code and Codex\n([\s\S]*?)\n### Claude Code only/)?.[1] ?? "";
const claudeOnlySection = readme.match(/### Claude Code only\n([\s\S]*?)\n## Install/)?.[1] ?? "";
const sharedNames = [...sharedSection.matchAll(/\]\(skills\/([a-z0-9-]+)\)/g)].map((match) => match[1]).sort();
const claudeOnlyNames = [...claudeOnlySection.matchAll(/\]\(skills\/([a-z0-9-]+)\)/g)].map((match) => match[1]).sort();
const expectedClaudeOnly = allSkillNames.filter((name) => !markerNames.includes(name));
if (JSON.stringify(sharedNames) !== JSON.stringify(markerNames)) {
  fail(`README shared section differs from Codex markers: README=${sharedNames.join(",")} markers=${markerNames.join(",")}`);
}
if (JSON.stringify(claudeOnlyNames) !== JSON.stringify(expectedClaudeOnly)) {
  fail(`README Claude-only section is wrong: README=${claudeOnlyNames.join(",")} expected=${expectedClaudeOnly.join(",")}`);
}
const claudeAdapter = read("CLAUDE.md").trim();
if (claudeAdapter !== "@AGENTS.md") fail("CLAUDE.md must be exactly @AGENTS.md");

if (failures.length) {
  for (const message of failures) console.error(`FAIL: ${message}`);
  process.exit(1);
}

console.log(`PASS: ${skillDirs.length} skills; ${markerNames.length} Codex markers; manifests ${claudeManifest.version}`);
