# Codex Status Bar

A tiny native macOS menu-bar app that shows live Codex task state across Codex CLI and Codex Desktop.

It uses Codex's documented lifecycle hooks to show when Codex is thinking, using a tool, waiting for permission, or idle. Multiple sessions are aggregated so a permission request is never hidden behind ordinary work.

## What it shows

- The selected local Codex pet from `~/.codex/pets` when idle.
- The pet's native active-work frames while Codex runs and waiting pose when approval is needed.
- A yellow indicator when Codex needs permission.
- Optional elapsed time and thinking words.
- Session rows with project, surface, and state.

The app is local-only. It does not read message content, collect telemetry, use an API key, or require Node, npm, Bun, or another runtime. To recover immediately when Esc interrupts a turn, it checks only the structured event envelopes at the tail of the active local session file for Codex's `turn_aborted` marker.

## Build and install

Requirements: macOS 12+ and Xcode Command Line Tools.

```bash
./build.sh
open build/CodexStatusBar.app
```

For a DMG:

```bash
./build.sh --dmg
```

On first launch, Codex Status Bar asks before changing anything. Choose **Install** to merge its commands into `~/.codex/hooks.json`. Existing hooks are preserved and the original file is backed up once.

Then open `/hooks` in Codex, review the six Codex Status Bar commands, and trust them. Codex intentionally skips new hooks until you approve their exact definitions.

## Supported events

- `SessionStart`
- `UserPromptSubmit`
- `PreToolUse`
- `PostToolUse`
- `PermissionRequest`
- `Stop`

CLI sessions are removed when their Codex process exits. Codex currently has no documented `SessionEnd` hook, so idle Desktop rows expire by age.

## Uninstall hooks

Use **Reinstall Hooks…** to repair moved helper paths. Choose **Uninstall Hooks…** to remove only Codex Status Bar's marked commands while preserving every unrelated hook.

## Testing

```bash
scripts/test.sh
swiftc -typecheck Sources/*.swift -framework Cocoa
./build.sh
```

See [PRIVACY.md](PRIVACY.md), [TROUBLESHOOTING.md](TROUBLESHOOTING.md), and [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT
