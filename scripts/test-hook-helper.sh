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
stop_output="$(printf '%s' "$payload" | CODEX_STATUSBAR_HOME="$home" build/tests/CodexStatusHook Stop)"
jq -e '.state == "done" and .startedAt == 0' "$state" >/dev/null
test "$stop_output" = '{}'

printf '%s' "$payload" | CODEX_STATUSBAR_HOME="$home" build/tests/CodexStatusHook UserPromptSubmit
agent_one="$(jq -cn --argjson base "$payload" '$base + {agent_id:"agent-one",agent_type:"explorer"}')"
agent_two="$(jq -cn --argjson base "$payload" '$base + {agent_id:"agent-two",agent_type:"reviewer"}')"
printf '%s' "$agent_one" | CODEX_STATUSBAR_HOME="$home" build/tests/CodexStatusHook SubagentStart
jq -e '.state == "subagent" and .activeAgents == ["agent-one"]' "$state" >/dev/null
printf '%s' "$agent_two" | CODEX_STATUSBAR_HOME="$home" build/tests/CodexStatusHook SubagentStart
jq -e '.state == "subagent" and (.activeAgents | length) == 2' "$state" >/dev/null
subagent_stop_output="$(printf '%s' "$agent_one" | CODEX_STATUSBAR_HOME="$home" build/tests/CodexStatusHook SubagentStop)"
test "$subagent_stop_output" = '{}'
jq -e '.state == "subagent" and .activeAgents == ["agent-two"]' "$state" >/dev/null
printf '%s' "$agent_two" | CODEX_STATUSBAR_HOME="$home" build/tests/CodexStatusHook SubagentStop >/dev/null
jq -e '.state == "thinking" and .activeAgents == []' "$state" >/dev/null

printf '%s' "$payload" | CODEX_STATUSBAR_HOME="$home" build/tests/CodexStatusHook UserPromptSubmit
for i in $(seq 1 12); do
    agent="$(jq -cn --argjson base "$payload" --arg id "parallel-$i" '$base + {agent_id:$id,agent_type:"worker"}')"
    printf '%s' "$agent" | CODEX_STATUSBAR_HOME="$home" build/tests/CodexStatusHook SubagentStart &
done
wait
jq -e '.state == "subagent" and (.activeAgents | length) == 12' "$state" >/dev/null

echo "HookHelperTests: 7 passed"
