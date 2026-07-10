# Privacy

Codex Status Bar runs locally and collects no telemetry.

The hook helper receives Codex's documented hook metadata and stores status, timestamps, project directory, model identifier, tool name, surface, process identifiers, current turn ID, and session-file path under `~/.codex/statusbar/state.d`. The app reads at most the final 32 KB of the active local session file and inspects only JSON event envelopes for a matching `turn_aborted` event so Esc clears working state immediately. It never reads message content.

The app makes no network requests. It modifies `~/.codex/hooks.json` only after explicit confirmation and creates at most one backup named `hooks.json.bak-codex-statusbar`.
