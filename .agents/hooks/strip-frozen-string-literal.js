#!/usr/bin/env node

const fs = require("node:fs");
const path = require("node:path");

function filePath(payload) {
  if (typeof payload.file_path === "string") return payload.file_path;
  if (typeof payload.filePath === "string") return payload.filePath;
  if (typeof payload.path === "string") return payload.path;
  const input = payload.tool_input;
  if (input && typeof input.file_path === "string") return input.file_path;
  if (input && typeof input.path === "string") return input.path;
  return "";
}

function insideProject(file) {
  const root = path.resolve(process.cwd());
  const resolved = path.resolve(file);
  return resolved === root || resolved.startsWith(`${root}${path.sep}`);
}

let raw = "";
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => {
  raw += chunk;
});
process.stdin.on("end", () => {
  let payload = {};
  try {
    payload = raw.trim() ? JSON.parse(raw) : {};
  } catch {
    process.stdout.write("{}\n");
    return;
  }

  const file = filePath(payload);
  if (!file.endsWith(".rb") || !insideProject(file)) {
    process.stdout.write("{}\n");
    return;
  }

  let text;
  try {
    text = fs.readFileSync(file, "utf8");
  } catch {
    process.stdout.write("{}\n");
    return;
  }

  const next = text.replace(/^[ \t]*#[ \t]*frozen_string_literal:\s*true[ \t]*\r?\n/, "");
  if (next !== text) fs.writeFileSync(file, next);
  process.stdout.write("{}\n");
});
