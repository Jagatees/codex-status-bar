#!/usr/bin/env node
"use strict";

const cp = require("child_process");
const {
  compactText,
  identifiers,
  readState,
  toolName,
  toolStatus,
  writeState,
} = require("./state");

let inputText = "";
let finished = false;
process.stdin.setEncoding("utf8");
process.stdin.on("data", (chunk) => { inputText += chunk; });
process.stdin.on("end", run);
process.stdin.on("error", run);
setTimeout(run, 900).unref();

function launchApp() {
  const appPath = process.env.CODEX_STATUS_BAR_APP;
  const args = appPath ? ["-g", appPath] : ["-g", "-b", "com.jagatees.codexstatusbar"];
  try { cp.spawn("/usr/bin/open", args, { detached: true, stdio: "ignore" }).unref(); } catch {}
}

function run() {
  if (finished) return;
  finished = true;
  try {
    const input = inputText.trim() ? JSON.parse(inputText) : {};
    const event = process.argv[2] || input.hook_event_name || input.hookEventName || "";
    const ids = identifiers(input);
    const current = readState();
    const startedAt = current.started_at || new Date().toISOString();
    const name = toolName(input);

    switch (event.toLowerCase()) {
      case "sessionstart":
      case "session_start":
        launchApp();
        writeState({ ...ids, status: "idle", label: "Idle", tool_name: null, error: null });
        break;
      case "userpromptsubmit":
      case "user_prompt_submit":
        writeState({ ...ids, status: "thinking", label: "Thinking", started_at: new Date().toISOString(), completed_at: null, tool_name: null, error: null });
        break;
      case "pretooluse":
      case "pre_tool_use": {
        const [status, label] = toolStatus(name);
        writeState({ ...ids, status, label, tool_name: name, started_at: startedAt, completed_at: null, error: null });
        break;
      }
      case "permissionrequest":
      case "permission_request":
        writeState({ ...ids, status: "waiting_permission", label: "Waiting for permission", tool_name: name, started_at: startedAt, error: null });
        break;
      case "posttooluse":
      case "post_tool_use":
        writeState({ ...ids, status: "thinking", label: "Thinking", tool_name: null, started_at: startedAt, error: null });
        break;
      case "stop":
        writeState({ ...ids, status: "complete", label: "Turn complete", tool_name: null, completed_at: new Date().toISOString(), last_message: compactText(input.last_assistant_message || input.last_message || input.message), error: null });
        break;
      default:
        break;
    }
  } catch (error) {
    try { writeState({ status: "error", label: "Hook error", error: compactText(error.message) }); } catch {}
  }
}
