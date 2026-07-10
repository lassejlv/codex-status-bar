#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/tests
swiftc Sources/HookCore.swift HookHelper/main.swift -o build/tests/CodexStatusHook
home="$(mktemp -d)"
trap 'rm -rf "$home"' EXIT
payload='{"session_id":"abc-123","cwd":"/tmp/example","model":"gpt-5","turn_id":"turn-1"}'
printf '%s' "$payload" | CODEX_STATUSBAR_HOME="$home" build/tests/CodexStatusHook UserPromptSubmit
state="$home/.codex/statusbar/state.d/abc-123.json"
test -f "$state"
jq -e '.state == "thinking" and .project == "example" and .sessionId == "abc-123"' "$state" >/dev/null
printf '%s' "$payload" | CODEX_STATUSBAR_HOME="$home" build/tests/CodexStatusHook Stop
jq -e '.state == "done" and .startedAt == 0' "$state" >/dev/null
echo "HookHelperTests: 2 passed"
