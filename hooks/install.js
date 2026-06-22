#!/usr/bin/env node
"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");
const cp = require("child_process");

const home = process.env.CODEX_HOME || path.join(os.homedir(), ".codex");
const targetDir = path.join(home, "statusbar");
const targetHooksDir = path.join(targetDir, "hooks");
const hooksPath = path.join(home, "hooks.json");
const configPath = path.join(home, "config.toml");
const marker = path.join(targetDir, "hooks");
const notifyMarker = "# codex-status-bar-notify";
const sourceDir = process.env.CODEX_STATUS_BAR_SOURCE_DIR || __dirname;
const node = process.execPath;

function backup(file) {
  if (!fs.existsSync(file)) return;
  const backupPath = `${file}.bak-codex-status-bar`;
  if (!fs.existsSync(backupPath)) fs.copyFileSync(file, backupPath);
}

function quote(value) {
  return `"${String(value).replace(/(["\\$`])/g, "\\$1")}"`;
}

function stripOurs(entries) {
  return (entries || [])
    .map((entry) => ({
      ...entry,
      hooks: (entry.hooks || []).filter((hook) => !String(hook.command || "").includes(marker)),
    }))
    .filter((entry) => entry.hooks.length > 0);
}

function add(hooks, event, matcher) {
  const command = `${quote(node)} ${quote(path.join(targetHooksDir, "codex-status-hook.js"))} ${event}`;
  hooks[event] = stripOurs(hooks[event]);
  const entry = { hooks: [{ type: "command", command, timeout: 5 }] };
  if (matcher) entry.matcher = matcher;
  hooks[event].push(entry);
}

function install() {
  fs.mkdirSync(targetHooksDir, { recursive: true, mode: 0o700 });
  for (const file of ["state.js", "codex-status-hook.js", "codex-notify.js"]) {
    fs.copyFileSync(path.join(sourceDir, file), path.join(targetHooksDir, file));
    fs.chmodSync(path.join(targetHooksDir, file), 0o700);
  }

  backup(hooksPath);
  let document = {};
  if (fs.existsSync(hooksPath)) document = JSON.parse(fs.readFileSync(hooksPath, "utf8"));
  document.hooks = document.hooks || {};
  add(document.hooks, "SessionStart", "startup|resume|clear|compact");
  add(document.hooks, "UserPromptSubmit");
  add(document.hooks, "PreToolUse", "*");
  add(document.hooks, "PermissionRequest", "*");
  add(document.hooks, "PostToolUse", "*");
  add(document.hooks, "Stop");
  fs.writeFileSync(hooksPath, `${JSON.stringify(document, null, 2)}\n`, { mode: 0o600 });

  backup(configPath);
  let config = fs.existsSync(configPath) ? fs.readFileSync(configPath, "utf8") : "";
  const notifyPath = path.join(targetHooksDir, "codex-notify.js");
  const ownedLine = `notify = [${JSON.stringify(node)}, ${JSON.stringify(notifyPath)}] ${notifyMarker}`;
  const lines = config.split(/\r?\n/).filter((line) => !line.includes(notifyMarker));
  const existingNotify = lines.some((line) => /^\s*notify\s*=/.test(line) && !line.trimStart().startsWith("#"));
  if (!existingNotify) lines.push(ownedLine);
  config = `${lines.join("\n").replace(/^\n+/, "").replace(/\n+$/, "")}\n`;
  fs.writeFileSync(configPath, config, { mode: 0o600 });

  console.log(`Installed Codex Status Bar hooks in ${hooksPath}`);
  console.log(`Backup files use the suffix .bak-codex-status-bar`);
  if (existingNotify) console.log("Kept your existing notify command; Stop hooks still report completion.");
  console.log("Restart Codex, then run /hooks to review and trust the new hooks.");

  if (process.argv.includes("--from-app")) {
    try { cp.spawn("/usr/bin/open", ["-g", "-b", "com.jagatees.codexstatusbar"], { detached: true, stdio: "ignore" }).unref(); } catch {}
  }
}

try { install(); } catch (error) {
  console.error(`Codex Status Bar install failed: ${error.message}`);
  process.exitCode = 1;
}
