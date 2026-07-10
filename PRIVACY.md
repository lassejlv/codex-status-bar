# Privacy

Codex Status Bar runs locally and collects no telemetry.

The hook helper receives Codex's documented hook metadata and stores only status, timestamps, project directory, model identifier, tool name, surface, and process identifiers under `~/.codex/statusbar/state.d`. It does not read the transcript path or conversation content.

The app makes no network requests. It modifies `~/.codex/hooks.json` only after explicit confirmation and creates at most one backup named `hooks.json.bak-codex-statusbar`.
