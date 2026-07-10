# Codex Status Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the existing Claude-only menu-bar app into a native, dependency-free Codex CLI and Codex Desktop status app.

**Architecture:** A Foundation-only Swift core maps Codex hook payloads and safely merges hook configuration. A bundled Swift command-line helper writes atomic per-session state, while the existing AppKit process aggregates and renders those states. First-launch AppKit consent gates all writes to `~/.codex/hooks.json`.

**Tech Stack:** Swift 5/AppKit/Foundation, Bash build tooling, Codex lifecycle hooks, SVG resource.

## Global Constraints

- Support macOS 12+, arm64 and x86_64.
- Do not read transcripts, send telemetry, or require an external runtime.
- Never modify `~/.codex/hooks.json` without native-window confirmation.
- Preserve unrelated hook configuration and use atomic writes.
- Use `codex.svg` as the menu-bar mark.

---

### Task 1: Testable Codex Hook Core

**Files:**
- Create: `Sources/HookCore.swift`
- Create: `Tests/HookCoreTests.swift`
- Create: `scripts/test.sh`

**Interfaces:**
- Produces: `HookEventMapper.update(payload:event:previous:pid:now:)`, `HookConfiguration.install(existing:helperPath:)`, and `HookConfiguration.uninstall(existing:)`.

- [ ] Write tests for supported events, malformed input, safe IDs, merge idempotency, preservation, and uninstall.
- [ ] Run `scripts/test.sh` and confirm the new symbols fail to compile.
- [ ] Implement the minimal Foundation-only core.
- [ ] Run `scripts/test.sh` and confirm all tests pass.

### Task 2: Native Hook Executable

**Files:**
- Create: `HookHelper/main.swift`
- Modify: `build.sh`

**Interfaces:**
- Consumes: `HookEventMapper` from Task 1.
- Produces: `CodexStatusHook <event>` bundled in `Contents/Resources`.

- [ ] Add an isolated hook simulation test using a temporary `HOME`.
- [ ] Run it and confirm failure before the helper exists.
- [ ] Implement stdin parsing, previous-state preservation, atomic write, and `SessionStart` app launch.
- [ ] Update the build to compile a universal helper and bundle `codex.svg`.
- [ ] Run unit and simulation tests.

### Task 3: Consent-Gated Hook Installation

**Files:**
- Modify: `Sources/main.swift`

**Interfaces:**
- Consumes: `HookConfiguration` from Task 1 and the bundled helper path.
- Produces: first-launch Install/Not Now alert, menu reinstall action, trust guidance, and safe config writes.

- [ ] Add configuration fixtures covering invalid JSON and byte preservation.
- [ ] Verify the fixture test fails before installer integration exists.
- [ ] Replace automatic Claude installation with explicit AppKit consent.
- [ ] Add atomic backup/write behavior and `/hooks` trust guidance.
- [ ] Run tests and Swift type checking.

### Task 4: Codex App Identity and State Model

**Files:**
- Modify: `Sources/main.swift`
- Modify: `build.sh`
- Modify: `.claude-plugin/marketplace.json`
- Modify: `.claude-plugin/plugin.json`
- Modify: `hooks/hooks.json`
- Delete: `hooks/install.js`, `hooks/lifecycle.js`, `hooks/update.js`, `hooks/uninstall.js`

**Interfaces:**
- Consumes: state JSON written by `CodexStatusHook`.
- Produces: Codex session aggregation under `~/.codex/statusbar/state.d`.

- [ ] Add priority and version assertions to the Swift test harness.
- [ ] Replace Claude paths, bundle IDs, names, surface labels, and tool semantics.
- [ ] Replace plugin hooks with `PLUGIN_ROOT` commands for the native helper where applicable.
- [ ] Remove all Node lifecycle scripts and upstream release checks.
- [ ] Run tests and search for remaining functional Claude references.

### Task 5: Codex Icon and Motion

**Files:**
- Modify: `Sources/main.swift`
- Add: `codex.svg`
- Delete: `Sources/CrabFrames.swift`, `Sources/CrabRender.swift`, `Sources/SparkFrames.swift`, `Sources/LogoFrame.swift`

**Interfaces:**
- Produces: static resting mark and pulsing/alternating-rotation working mark.

- [ ] Add a pure animation-state assertion for reduced motion.
- [ ] Load `codex.svg` from bundle and render it as orange or a system template.
- [ ] Replace animation-style selection with an Animate Codex icon toggle.
- [ ] Respect `NSWorkspace.shared.accessibilityDisplayShouldReduceMotion`.
- [ ] Run tests, type checking, and build.

### Task 6: Documentation and Release Verification

**Files:**
- Modify: `README.md`, `PRIVACY.md`, `TROUBLESHOOTING.md`, `CONTRIBUTING.md`, `CHANGELOG.md`, `ACKNOWLEDGEMENTS.md`

- [ ] Rewrite user documentation for consent, `/hooks` trust, supported Codex surfaces, privacy, build, and uninstall.
- [ ] Run `scripts/test.sh`, `bash -n build.sh`, Swift type checking, and `./build.sh`.
- [ ] Inspect bundle identifiers, resources, signatures, and both binary architectures.
- [ ] Review `git diff --check`, remaining Claude references, and repository status.
