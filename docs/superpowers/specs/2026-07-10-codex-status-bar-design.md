# Codex Status Bar Design

## Purpose

Rework the existing Claude Status Bar codebase into Codex Status Bar, a small native macOS menu-bar app that reports live Codex task state. The app targets both Codex CLI and Codex Desktop when those surfaces emit Codex lifecycle hooks.

The app stays local, dependency-free at runtime, and narrowly focused on status. It does not read conversation content, send telemetry, call an AI API, or scrape unstable Codex transcript formats.

## Product Scope

Codex Status Bar shows:

- A resting Codex icon when no task is active.
- A subtly pulsing and rotating Codex icon while Codex is thinking or using a tool.
- An elapsed timer for the active turn when the timer setting is enabled.
- A yellow waiting indicator when Codex requests permission.
- A menu listing live sessions with project, Git branch, surface, state, and elapsed time.
- The highest-priority live session in the menu bar when multiple sessions exist.

Priority order is permission request, active work, then idle. Ties use the most recent event.

The app supports macOS 12 and newer and keeps a universal arm64 and x86_64 build.

## Codex Integration

Codex Status Bar uses the documented Codex lifecycle hook interface. It installs command hooks for:

- `SessionStart`
- `UserPromptSubmit`
- `PreToolUse`
- `PostToolUse`
- `PermissionRequest`
- `Stop`

Every hook receives JSON on standard input. The implementation uses documented common fields including `session_id`, `cwd`, `transcript_path`, `hook_event_name`, and `model`, plus event-specific fields such as `turn_id` and `tool_name`.

The app does not inspect transcript messages. Because Codex does not emit `Stop` when Esc interrupts a turn, the app may read a bounded tail of the active local session file and parse only structured event envelopes for a `turn_aborted` event matching the current `turn_id`.

Codex does not currently document a `SessionEnd` event. CLI state is therefore reaped when the recorded parent Codex process exits. Desktop session files expire after a conservative idle period so a long-running desktop process cannot keep obsolete rows forever. The app itself may remain available while Codex Desktop is running.

Source: [Codex hooks documentation](https://learn.chatgpt.com/docs/hooks).

## Native Hook Helper

The bundle contains a small universal Swift command-line helper dedicated to hook processing. It has no dependency on Bun, Node.js, npm, shell startup files, or third-party packages.

The helper:

1. Reads one hook payload from standard input.
2. Validates and sanitizes the session identifier used as a filename.
3. Maps the hook event to a normalized session state.
4. Preserves useful state from the prior event when a payload omits it.
5. Writes JSON to a temporary file and atomically renames it into place.
6. Launches Codex Status Bar in the background on `SessionStart`.
7. Exits successfully and silently when it receives malformed or unsupported input.

State files live under `~/.codex/statusbar/state.d/<session-id>.json`.

Normalized states are:

- `idle`
- `thinking`
- `tool`
- `permission`
- `done`

Tool labels remain short and human-readable. Known examples include Running command for shell tools, Editing for `apply_patch`, Reading for filesystem reads, Searching for search tools, and Using tool as the fallback.

## Installation Consent and Hook Trust

The app never modifies Codex configuration without explicit user consent.

On first launch, an AppKit confirmation window explains:

- The target path: `~/.codex/hooks.json`.
- The lifecycle events being installed.
- That hooks write only local status metadata.
- That existing hooks are preserved.
- That Codex requires the new hook definitions to be reviewed and trusted.

The window provides Install and Not Now actions. Closing the window is equivalent to Not Now. The app does not repeatedly interrupt the user; installation remains available from the status menu.

After Install:

1. Create `~/.codex` if needed.
2. Parse the existing `hooks.json`, failing without modification if it is invalid.
3. Create a one-time backup at `~/.codex/hooks.json.bak-codex-statusbar` when an original file exists.
4. Remove stale entries carrying the Codex Status Bar marker.
5. Append the current absolute helper commands while preserving unrelated entries and ordering.
6. Write the new configuration atomically.
7. Show a success screen telling the user to open `/hooks` in Codex and trust the new definitions.

Codex may skip the hooks until trust is granted. The status menu provides a Review Hooks explanation when no trusted events have arrived.

The uninstaller removes only hook handlers whose commands contain the unique Codex Status Bar marker. It leaves unrelated match groups and handlers intact and deletes an empty event only when no handlers remain.

## App Identity and Packaging

The fork uses:

- Product name: Codex Status Bar
- Executable: `CodexStatusBar`
- Bundle identifier: `com.local.codexstatusbar`
- State directory: `~/.codex/statusbar`
- Initial fork version: `0.1.0`

The build script compiles the AppKit app and native hook helper for arm64 and x86_64, combines each binary with `lipo`, embeds the helper and icon resources, then signs the bundle. DMG packaging remains available, but all Claude-specific signing profile names, volume names, filenames, and copy are replaced.

The supplied SVG is retained as source material, but its CoreSVG rendering is unreliable at menu-bar size. The app bundles the locally installed full-color Codex pet-style app mark as a stable high-resolution PNG.

Release checks are disabled until this fork has an explicit repository URL. The app must not continue checking the upstream Claude Status Bar repository.

## Menu and Animation

The existing AppKit menu, session rows, branch discovery, multi-session aggregation, and timer rendering remain where provider-neutral.

Claude-specific animation assets and names are removed. Working state uses the Codex mark with a restrained animation:

- A small scale pulse centered on the icon.
- A subtle alternating rotation rather than continuous spinning.
- No animation while idle, done, or waiting for permission.
- The animation stops immediately when effective state changes.

Settings are:

- Animate Codex icon
- Show timer
- Thinking words
- Hide idle sessions after a selected duration

Reduced-motion behavior disables pulse and rotation and keeps a static working icon. The status label and timer continue to update.

The menu provides Install Hooks or Reinstall Hooks, Review Hooks guidance, version information, and Quit. Claude-specific Open Claude actions and Claude animation choices are removed.

## Surface Detection

The helper records the hook process parent PID and available documented payload metadata. The app classifies a session as CLI or App only when process or environment evidence is reliable. Otherwise the surface badge is Codex rather than guessing.

CLI row activation brings the originating terminal forward when the terminal can be identified safely. Desktop row activation opens or focuses Codex Desktop. If reliable session-specific navigation is unavailable, activation focuses the owning application without pretending to select an exact task.

## Failure Handling

- Missing or malformed hook input does not block a Codex task.
- Invalid existing `hooks.json` is never overwritten; the confirmation window reports the parse error and path.
- Atomic writes prevent partially written configuration or session state.
- A missing state directory is created on demand.
- Unsupported hook events are ignored.
- Dead CLI processes are reaped.
- Stale desktop sessions expire without deleting Codex data.
- If the helper moves because the app bundle moves, Reinstall Hooks refreshes absolute command paths.
- If hooks are untrusted or disabled, the app explains that state without trying to bypass Codex trust.

## Testing Strategy

All behavior that can be isolated from AppKit rendering is tested through deterministic Swift tests or helper-level command tests.

Required automated coverage:

- Each supported hook event maps to the expected state and label.
- Unknown events and malformed JSON are ignored successfully.
- Session identifiers cannot escape the state directory.
- State updates preserve fields omitted by later events.
- Session state writes are atomic.
- Hook configuration installation preserves unrelated hooks.
- Reinstallation is idempotent and replaces stale marked commands.
- Uninstall removes only marked handlers.
- Invalid existing configuration is preserved byte-for-byte.
- Session priority selects permission over work and work over idle.
- Version comparison remains numeric by component.
- Reduced-motion state disables icon animation.

Integration verification uses a temporary home directory and fixture hook payloads. It must never write to the developer's real `~/.codex/hooks.json` during automated tests.

Release verification includes:

- Swift tests.
- Swift type checking.
- Hook fixture simulations.
- Shell syntax validation for the build script.
- A full universal app build.
- Bundle inspection for both architectures, identifiers, helper location, and resources.
- Manual smoke testing in Codex CLI and Codex Desktop, including hook trust, working state, tool state, permission state, completion, and multi-session priority.

## Documentation

README, privacy, troubleshooting, contributing, changelog, plugin metadata, and uninstall instructions are rewritten for Codex Status Bar. Documentation must state:

- Supported Codex surfaces are limited to those that emit the documented hooks.
- First launch requires consent and Codex hook trust review.
- No conversation content or telemetry is collected.
- The only files written are the hook configuration backup, marked hook entries, local status state, and app preferences.
- The app has no external runtime dependency.

## Out of Scope

- Parsing conversation messages or private app databases.
- Usage, token, cost, or rate-limit dashboards.
- Sending task data to a server.
- Automatically bypassing Codex hook trust.
- Linux or Windows ports.
- Exact navigation to a desktop task without a documented stable interface.
- Supporting Claude alongside Codex in the same app.
