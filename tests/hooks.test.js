"use strict";

const assert = require("node:assert/strict");
const fs = require("node:fs");
const os = require("node:os");
const path = require("node:path");
const { spawnSync } = require("node:child_process");
const test = require("node:test");

const root = path.resolve(__dirname, "..");

function tempHome() {
  return fs.mkdtempSync(path.join(os.tmpdir(), "codex-status-bar-test-"));
}

function run(script, args, options = {}) {
  return spawnSync(process.execPath, [path.join(root, "hooks", script), ...args], {
    encoding: "utf8",
    input: options.input,
    env: { ...process.env, CODEX_HOME: options.home, CODEX_STATUS_BAR_SOURCE_DIR: path.join(root, "hooks") },
  });
}

function state(home) {
  return JSON.parse(fs.readFileSync(path.join(home, "statusbar", "state.json"), "utf8"));
}

test("hook maps prompt, tool, permission, and stop states", () => {
  const home = tempHome();
  let result = run("codex-status-hook.js", ["UserPromptSubmit"], { home, input: JSON.stringify({ session_id: "s1", cwd: "/tmp/project" }) });
  assert.equal(result.status, 0);
  assert.equal(state(home).status, "thinking");

  result = run("codex-status-hook.js", ["PreToolUse"], { home, input: JSON.stringify({ tool_name: "apply_patch" }) });
  assert.equal(result.status, 0);
  assert.equal(state(home).status, "editing");

  run("codex-status-hook.js", ["PermissionRequest"], { home, input: JSON.stringify({ tool_name: "Bash" }) });
  assert.equal(state(home).status, "waiting_permission");

  run("codex-status-hook.js", ["Stop"], { home, input: JSON.stringify({ last_assistant_message: "done ".repeat(50) }) });
  assert.equal(state(home).status, "complete");
  assert.ok(state(home).last_message.length <= 120);
});

test("notify handles agent-turn-complete", () => {
  const home = tempHome();
  const payload = JSON.stringify({ type: "agent-turn-complete", thread_id: "t1", last_assistant_message: "Finished" });
  const result = run("codex-notify.js", [payload], { home });
  assert.equal(result.status, 0);
  assert.equal(state(home).status, "complete");
  assert.equal(state(home).last_message, "Finished");
});

test("installer is idempotent and uninstaller preserves unrelated config", () => {
  const home = tempHome();
  fs.mkdirSync(home, { recursive: true });
  fs.writeFileSync(path.join(home, "hooks.json"), JSON.stringify({ hooks: { Stop: [{ hooks: [{ type: "command", command: "node /keep/me.js" }] }] } }));
  fs.writeFileSync(path.join(home, "config.toml"), "model = \"gpt-test\"\n");

  assert.equal(run("install.js", [], { home }).status, 0);
  assert.equal(run("install.js", [], { home }).status, 0);
  const hooks = JSON.parse(fs.readFileSync(path.join(home, "hooks.json"), "utf8"));
  assert.equal(hooks.hooks.Stop.length, 2);
  assert.equal(hooks.hooks.PreToolUse.length, 1);
  const config = fs.readFileSync(path.join(home, "config.toml"), "utf8");
  assert.equal((config.match(/codex-status-bar-notify/g) || []).length, 1);

  assert.equal(run("uninstall.js", [], { home }).status, 0);
  const after = JSON.parse(fs.readFileSync(path.join(home, "hooks.json"), "utf8"));
  assert.equal(after.hooks.Stop.length, 1);
  assert.equal(after.hooks.Stop[0].hooks[0].command, "node /keep/me.js");
  assert.match(fs.readFileSync(path.join(home, "config.toml"), "utf8"), /model = "gpt-test"/);
  assert.doesNotMatch(fs.readFileSync(path.join(home, "config.toml"), "utf8"), /codex-status-bar-notify/);
});

test("installer does not replace an existing notify command", () => {
  const home = tempHome();
  fs.mkdirSync(home, { recursive: true });
  fs.writeFileSync(path.join(home, "config.toml"), "notify = [\"my-notifier\"]\n");
  assert.equal(run("install.js", [], { home }).status, 0);
  const config = fs.readFileSync(path.join(home, "config.toml"), "utf8");
  assert.match(config, /notify = \["my-notifier"\]/);
  assert.doesNotMatch(config, /codex-status-bar-notify/);
});
