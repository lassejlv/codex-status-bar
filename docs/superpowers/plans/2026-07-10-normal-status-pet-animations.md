# Normal Status Pet Animations Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace playful thinking copy with stable status labels and render the selected Codex pet's standard animation row for each activity.

**Architecture:** Put the pet animation contract and tool-to-animation mapping in `HookCore.swift` so the native hook helper and AppKit renderer share stable string values. Persist the selected animation and alternating command direction in each session state file. Keep image cropping in `main.swift`, but drive its row, column, and timing from the tested core animation specification.

**Tech Stack:** Swift 5, AppKit, Foundation, CoreGraphics, shell build scripts, universal macOS 12+ binaries.

## Global Constraints

- Thinking always displays `Thinking…`; known tools retain `Running command`, `Editing`, `Reading`, `Searching`, `Browsing web`, or `Using tool`.
- Use standard Codex pet atlas rows 0 through 8 and never treat v2 look-direction rows 9 and 10 as activity animations.
- Respect Reduce Motion and the existing `Animate pet` toggle by showing the first frame of the selected row.
- Preserve timer behavior, permission priority and amber indicator, multi-session aggregation, fallback icon behavior, and Esc interruption detection.
- Do not infer tool failure by inspecting message or tool-output text.

---

### Task 1: Shared animation and hook-state contract

**Files:**
- Modify: `Tests/HookCoreTests.swift:13-88`
- Modify: `Sources/HookCore.swift:50-153`

**Interfaces:**
- Produces: `PetAnimation`, `PetAnimation.spec`, `PetAnimation.column(atMilliseconds:)`, `PetAnimation.totalDurationMilliseconds`, `HookEventMapper.toolAnimation(_:)`.
- Produces state-file keys: `animation: String` and `commandRow: Int`.
- Consumes: existing hook payload, prior state dictionary, and `toolLabel(_:)` classification.

- [ ] **Step 1: Write failing animation-contract and mapper tests**

Add assertions covering all row numbers, representative frame boundaries, labels, and persisted direction alternation:

```swift
expect(PetAnimation.idle.spec.row == 0, "idle uses row zero")
expect(PetAnimation.runRight.spec.frameDurationsMilliseconds.count == 8, "run uses eight frames")
expect(PetAnimation.jump.totalDurationMilliseconds == 840, "jump lasts one standard loop")
expect(PetAnimation.working.column(atMilliseconds: 0) == 0, "working starts at first frame")
expect(PetAnimation.working.column(atMilliseconds: 121) == 1, "working advances by standard timing")
expect(HookEventMapper.toolAnimation("apply_patch") == .wave, "editing uses hand motion")
expect(HookEventMapper.toolAnimation("web__run") == .review, "web work uses review")
expect(prompt?["animation"] as? String == PetAnimation.working.rawValue, "prompt uses active work")
expect(tool?["animation"] as? String == PetAnimation.wave.rawValue, "editing persists wave")
```

Create two sequential Bash `PreToolUse` states and assert their animations are `runRight` then `runLeft` while `commandRow` survives the intervening `PostToolUse` state.

- [ ] **Step 2: Run the core tests and verify RED**

Run:

```bash
swiftc Sources/HookCore.swift Tests/HookCoreTests.swift -o build/tests/HookCoreTests && build/tests/HookCoreTests
```

Expected: compilation fails because `PetAnimation` and `toolAnimation(_:)` do not exist.

- [ ] **Step 3: Implement the minimal shared animation contract**

Add the typed animation values and the exact standard timings:

```swift
enum PetAnimation: String {
    case idle, runRight, runLeft, wave, jump, failed, waiting, working, review

    struct Spec {
        let row: Int
        let frameDurationsMilliseconds: [Int]
        let repeats: Bool
    }

    var spec: Spec {
        switch self {
        case .idle:     return Spec(row: 0, frameDurationsMilliseconds: [280, 110, 110, 140, 140, 320], repeats: true)
        case .runRight: return Spec(row: 1, frameDurationsMilliseconds: [120, 120, 120, 120, 120, 120, 120, 220], repeats: true)
        case .runLeft:  return Spec(row: 2, frameDurationsMilliseconds: [120, 120, 120, 120, 120, 120, 120, 220], repeats: true)
        case .wave:     return Spec(row: 3, frameDurationsMilliseconds: [140, 140, 140, 280], repeats: true)
        case .jump:     return Spec(row: 4, frameDurationsMilliseconds: [140, 140, 140, 140, 280], repeats: false)
        case .failed:   return Spec(row: 5, frameDurationsMilliseconds: [140, 140, 140, 140, 140, 140, 140, 240], repeats: false)
        case .waiting:  return Spec(row: 6, frameDurationsMilliseconds: [150, 150, 150, 150, 150, 260], repeats: true)
        case .working:  return Spec(row: 7, frameDurationsMilliseconds: [120, 120, 120, 120, 120, 220], repeats: true)
        case .review:   return Spec(row: 8, frameDurationsMilliseconds: [150, 150, 150, 150, 150, 280], repeats: true)
        }
    }
}
```

Implement `totalDurationMilliseconds` and `column(atMilliseconds:)` by accumulating durations, modulo the total for repeating animations and clamping one-shot animations to the last frame.

Map command tools to alternating `.runRight`/`.runLeft`, edit/write tools to `.wave`, read/search/browser tools to `.review`, unknown tools to `.working`, prompts and post-tool events to `.working`, permission to `.waiting`, stop to `.jump`, and session start to `.idle`. Persist both `animation.rawValue` and `commandRow` in every state update.

- [ ] **Step 4: Run the core tests and verify GREEN**

Run:

```bash
swiftc Sources/HookCore.swift Tests/HookCoreTests.swift -o build/tests/HookCoreTests && build/tests/HookCoreTests
```

Expected: `HookCoreTests` exits 0 and reports the updated assertion count.

- [ ] **Step 5: Commit the shared contract**

```bash
git add Sources/HookCore.swift Tests/HookCoreTests.swift
git commit -m "feat: map Codex actions to pet animations"
```

### Task 2: State-driven AppKit pet renderer

**Files:**
- Modify: `Sources/main.swift:250-359`
- Modify: `Sources/main.swift:875-906`
- Modify: `Sources/main.swift:954-1094`
- Test: `Tests/HookCoreTests.swift`

**Interfaces:**
- Consumes: `PetAnimation(rawValue:)`, `PetAnimation.spec`, `column(atMilliseconds:)`, and state-file `animation`.
- Produces: `Session.animation`, `render(label:animation:labelStartedAt:animationStartedAt:dot:)`, and row-aware `petIcon(animation:column:dotColor:)`.

- [ ] **Step 1: Write failing fallback and one-shot-state tests**

Add pure core helpers for backward-compatible state files and bounded completion rendering, then test their intended API:

```swift
expect(PetAnimation.fallback(state: "thinking", label: "Thinking…") == .working, "old thinking state uses active work")
expect(PetAnimation.fallback(state: "tool", label: "Searching") == .review, "old search state uses review")
expect(StatusPolicy.effectiveState(rawState: "done", age: 0.50) == "done", "completion remains visible during jump")
expect(StatusPolicy.effectiveState(rawState: "done", age: 0.85) == "idle", "completion expires after jump")
```

- [ ] **Step 2: Run the core tests and verify RED**

Run:

```bash
swiftc Sources/HookCore.swift Tests/HookCoreTests.swift -o build/tests/HookCoreTests && build/tests/HookCoreTests
```

Expected: compilation fails because `fallback(state:label:)` and `effectiveState(rawState:age:)` do not exist.

- [ ] **Step 3: Implement fallback and effective-state helpers**

Add `PetAnimation.fallback(state:label:)` using state first and known legacy labels second. Add `StatusPolicy.effectiveState(rawState:age:)` so `done` remains effective for `PetAnimation.jump.totalDurationMilliseconds / 1000.0`; keep other state aging and transcript-abort checks in the controller.

- [ ] **Step 4: Run the core tests and verify GREEN**

Run the command from Step 2. Expected: all assertions pass.

- [ ] **Step 5: Replace the fixed working-row renderer**

In `Session.init`, parse the persisted animation with a legacy fallback:

```swift
self.animation = (o["animation"] as? String).flatMap(PetAnimation.init(rawValue:))
    ?? PetAnimation.fallback(state: self.state, label: self.label)
```

Track `activeAnimation` and `animationStartedAt` separately from the optional elapsed-turn timer. Replace the fixed row-7 column calculation with:

```swift
let elapsedMS = max(0, Int((Date().timeIntervalSince1970 - animationStartedAt) * 1000))
let column = activeAnimation.column(atMilliseconds: elapsedMS)
button.image = petIcon(animation: activeAnimation, column: column, dotColor: activeDotColor)
```

Render idle, permission, thinking/tool, and done with `.idle`, `.waiting`, the session animation, and `.jump` respectively. Use the session state's `ts` as the animation start, keep `startedAt` only for the visible timer, animate idle and waiting when enabled, and display column zero when Reduce Motion or `Animate pet` disables animation. Preserve the amber overlay by composing it over the current waiting frame.

- [ ] **Step 6: Typecheck the AppKit app**

Run:

```bash
swiftc -typecheck Sources/*.swift -framework Cocoa
```

Expected: exit 0 with no diagnostics.

- [ ] **Step 7: Commit the renderer**

```bash
git add Sources/HookCore.swift Sources/main.swift Tests/HookCoreTests.swift
git commit -m "feat: render semantic pet animation rows"
```

### Task 3: Remove playful copy, document behavior, and verify the app

**Files:**
- Modify: `Sources/main.swift:302-354`
- Modify: `Sources/main.swift:515-532`
- Modify: `Sources/main.swift:740-762`
- Modify: `README.md:7-16`

**Interfaces:**
- Consumes: stable hook labels and semantic animation rendering from Tasks 1 and 2.
- Produces: options menu with only `Show timer` and `Animate pet`; user-facing documentation for semantic pet animations.

- [ ] **Step 1: Remove rotating thinking words**

Delete `useThinkingWords`, `sessionWord`, `thinkingWords`, the `thinkingWords` defaults read/write, the `Thinking words` toggle row, `updateThinkingWord(_:)`, and its session cleanup/evaluation calls. Simplify `workingLabel(_:)` to:

```swift
func workingLabel(_ session: Session) -> String {
    if !session.label.isEmpty { return session.label }
    return session.state == "tool" ? "Working…" : "Thinking…"
}
```

- [ ] **Step 2: Update the README**

Replace “active-work frames” and “thinking words” with a concise list stating that thinking uses `Thinking…`, known tools keep their action label, and the selected pet uses idle, directional running, hand-motion, review, waiting, and completion animations.

- [ ] **Step 3: Run the full automated verification**

Run:

```bash
scripts/test.sh
swiftc -typecheck Sources/*.swift -framework Cocoa
./build.sh
codesign --verify --deep --strict build/CodexStatusBar.app
lipo -archs build/CodexStatusBar.app/Contents/MacOS/CodexStatusBar
lipo -archs build/CodexStatusBar.app/Contents/Resources/CodexStatusHook
```

Expected: all tests pass; typecheck and build exit 0; code-sign verification exits 0; both binaries report `x86_64 arm64` or `arm64 x86_64`.

- [ ] **Step 4: Install and smoke-test locally**

Run:

```bash
pkill -x CodexStatusBar || true
rm -rf /Applications/CodexStatusBar.app
ditto build/CodexStatusBar.app /Applications/CodexStatusBar.app
open /Applications/CodexStatusBar.app
pgrep -fl CodexStatusBar
```

Expected: the installed app launches from `/Applications`; a live Codex action displays its normal label and the corresponding selected-pet animation; Esc returns the status to idle.

- [ ] **Step 5: Commit the user-facing cleanup**

```bash
git add Sources/main.swift README.md
git commit -m "refactor: simplify Codex status messages"
```
