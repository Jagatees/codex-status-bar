#!/usr/bin/env node
"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");

function codexHome() {
  return process.env.CODEX_HOME || path.join(os.homedir(), ".codex");
}

function statusDir() {
  return path.join(codexHome(), "statusbar");
}

function statePath() {
  return path.join(statusDir(), "state.json");
}

function readState() {
  try {
    return JSON.parse(fs.readFileSync(statePath(), "utf8"));
  } catch {
    return {};
  }
}

function now() {
  return new Date().toISOString();
}

function compactText(value, limit = 120) {
  if (typeof value !== "string") return null;
  const text = value.replace(/\s+/g, " ").trim();
  return text ? text.slice(0, limit) : null;
}

function writeState(patch) {
  const dir = statusDir();
  fs.mkdirSync(dir, { recursive: true, mode: 0o700 });
  const current = readState();
  const next = {
    version: 1,
    status: "idle",
    label: "Idle",
    session_id: null,
    turn_id: null,
    cwd: null,
    tool_name: null,
    started_at: null,
    updated_at: now(),
    completed_at: null,
    last_message: null,
    error: null,
    ...current,
    ...patch,
    version: 1,
    updated_at: now(),
  };
  const target = statePath();
  const temp = `${target}.${process.pid}.tmp`;
  fs.writeFileSync(temp, `${JSON.stringify(next, null, 2)}\n`, { mode: 0o600 });
  fs.renameSync(temp, target);
  return next;
}

function toolName(input) {
  return input.tool_name || input.toolName || input.tool || input.name ||
    input.tool_input?.name || input.params?.name || null;
}

function toolStatus(name) {
  const value = String(name || "");
  if (/^(Bash|shell|exec_command|write_stdin)$/i.test(value) || /terminal|command/i.test(value)) {
    return ["running_command", "Running command"];
  }
  if (/apply_patch|edit|write|create_file|delete_file/i.test(value)) {
    return ["editing", "Editing files"];
  }
  if (/read|fetch_file|list|search|find|glob|grep/i.test(value)) {
    return ["reading", "Reading files"];
  }
  return ["using_tool", "Using MCP tool"];
}

function identifiers(input) {
  return {
    session_id: input.session_id || input.sessionId || input.thread_id || input.threadId || null,
    turn_id: input.turn_id || input.turnId || null,
    cwd: input.cwd || input.working_directory || process.cwd(),
  };
}

module.exports = {
  codexHome,
  compactText,
  identifiers,
  now,
  readState,
  statePath,
  toolName,
  toolStatus,
  writeState,
};
