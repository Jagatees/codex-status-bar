#!/usr/bin/env node
"use strict";

const { compactText, identifiers, writeState } = require("./state");

try {
  const raw = process.argv.slice(2).join(" ");
  const input = raw ? JSON.parse(raw) : {};
  if (input.type === "agent-turn-complete") {
    writeState({
      ...identifiers(input),
      status: "complete",
      label: "Turn complete",
      tool_name: null,
      completed_at: new Date().toISOString(),
      last_message: compactText(input.last_assistant_message || input.last_message || input.message),
      error: null,
    });
  }
} catch (error) {
  try { writeState({ status: "error", label: "Notify error", error: compactText(error.message) }); } catch {}
}
