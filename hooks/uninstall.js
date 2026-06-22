#!/usr/bin/env node
"use strict";

const fs = require("fs");
const os = require("os");
const path = require("path");

const home = process.env.CODEX_HOME || path.join(os.homedir(), ".codex");
const marker = path.join(home, "statusbar", "hooks");
const hooksPath = path.join(home, "hooks.json");
const configPath = path.join(home, "config.toml");
const notifyMarker = "# codex-status-bar-notify";

try {
  if (fs.existsSync(hooksPath)) {
    const document = JSON.parse(fs.readFileSync(hooksPath, "utf8"));
    for (const event of Object.keys(document.hooks || {})) {
      document.hooks[event] = (document.hooks[event] || [])
        .map((entry) => ({ ...entry, hooks: (entry.hooks || []).filter((hook) => !String(hook.command || "").includes(marker)) }))
        .filter((entry) => entry.hooks.length > 0);
      if (document.hooks[event].length === 0) delete document.hooks[event];
    }
    fs.writeFileSync(hooksPath, `${JSON.stringify(document, null, 2)}\n`, { mode: 0o600 });
  }
  if (fs.existsSync(configPath)) {
    const config = fs.readFileSync(configPath, "utf8").split(/\r?\n/).filter((line) => !line.includes(notifyMarker)).join("\n");
    fs.writeFileSync(configPath, `${config.replace(/\n+$/, "")}\n`, { mode: 0o600 });
  }
  console.log("Removed Codex Status Bar configuration. Unrelated Codex settings and backup files were preserved.");
} catch (error) {
  console.error(`Codex Status Bar uninstall failed: ${error.message}`);
  process.exitCode = 1;
}
