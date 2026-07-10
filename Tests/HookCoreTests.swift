import Foundation

@main
struct HookCoreTests {
    static var failures = 0
    static var assertions = 0

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
        assertions += 1
        if !condition() { failures += 1; fputs("FAIL: \(message)\n", stderr) }
    }

    static func main() throws {
        let base: [String: Any] = [
            "session_id": "thread/../../unsafe",
            "cwd": "/tmp/project",
            "model": "gpt-5",
            "turn_id": "turn-1",
            "transcript_path": "/tmp/session.jsonl",
        ]
        let now = 1_750_000_000.0
        let prompt = HookEventMapper.update(payload: base, event: "UserPromptSubmit", previous: nil, pid: 42, now: now)
        expect(prompt?["state"] as? String == "thinking", "prompt starts thinking")
        expect(prompt?["animation"] as? String == PetAnimation.working.rawValue, "prompt uses active-work animation")
        expect(prompt?["startedAt"] as? Double == now, "prompt starts timer")
        expect(prompt?["sessionId"] as? String == "thread/../../unsafe", "raw session id remains metadata")
        expect(prompt?["transcript"] as? String == "/tmp/session.jsonl", "session event path is retained")
        expect(HookEventMapper.safeID("thread/../../unsafe") == "thread....unsafe", "unsafe filename characters are removed")

        var toolPayload = base
        toolPayload["tool_name"] = "apply_patch"
        let tool = HookEventMapper.update(payload: toolPayload, event: "PreToolUse", previous: prompt, pid: 42, now: now + 1)
        expect(tool?["state"] as? String == "tool", "pre-tool starts tool state")
        expect(tool?["label"] as? String == "Editing", "apply_patch gets editing label")
        expect(tool?["animation"] as? String == PetAnimation.wave.rawValue, "editing uses hand-motion animation")
        expect(tool?["startedAt"] as? Double == now, "tool preserves turn timer")

        let post = HookEventMapper.update(payload: base, event: "PostToolUse", previous: tool, pid: 42, now: now + 2)
        expect(post?["state"] as? String == "thinking", "post-tool resumes thinking")
        expect(post?["animation"] as? String == PetAnimation.working.rawValue, "post-tool resumes active-work animation")
        let permission = HookEventMapper.update(payload: toolPayload, event: "PermissionRequest", previous: post, pid: 42, now: now + 3)
        expect(permission?["state"] as? String == "permission", "permission request waits")
        expect(permission?["animation"] as? String == PetAnimation.waiting.rawValue, "permission uses waiting animation")
        expect(permission?["startedAt"] as? Double == 0, "permission clears timer")
        let stop = HookEventMapper.update(payload: base, event: "Stop", previous: permission, pid: 42, now: now + 4)
        expect(stop?["state"] as? String == "done", "stop completes turn")
        expect(stop?["animation"] as? String == PetAnimation.jump.rawValue, "completed turn uses jump animation")
        expect(HookEventMapper.update(payload: base, event: "Unknown", previous: nil, pid: 1, now: now) == nil, "unknown event is ignored")

        expect(PetAnimation.idle.spec.row == 0, "idle uses row zero")
        expect(PetAnimation.runRight.spec.frameDurationsMilliseconds.count == 8, "directional run uses eight frames")
        expect(PetAnimation.jump.totalDurationMilliseconds == 840, "jump lasts one standard loop")
        expect(PetAnimation.working.column(atMilliseconds: 0) == 0, "working starts at first frame")
        expect(PetAnimation.working.column(atMilliseconds: 119) == 0, "working holds its first frame")
        expect(PetAnimation.working.column(atMilliseconds: 120) == 1, "working advances on the standard boundary")
        expect(PetAnimation.working.column(atMilliseconds: 820) == 0, "repeating work wraps after one loop")
        expect(PetAnimation.jump.column(atMilliseconds: 2_000) == 4, "one-shot jump clamps to its final frame")
        expect(PetDisplaySize.small.points == 16, "small pet size is compact")
        expect(PetDisplaySize.normal.points == 20, "normal pet size preserves the current default")
        expect(PetDisplaySize.large.points == 24, "large pet size is visibly larger")
        expect(PetDisplaySize.from(persistedPoints: 99) == .normal, "invalid persisted size falls back safely")
        expect(PetAnimation.fallback(state: "thinking", label: "Thinking…") == .working, "old thinking state uses active work")
        expect(PetAnimation.fallback(state: "tool", label: "Searching") == .review, "old search state uses review")
        expect(PetAnimation.fallback(state: "tool", label: "Editing") == .wave, "old editing state uses hand motion")
        expect(PetAnimation.fallback(state: "permission", label: "Awaiting permission") == .waiting, "old permission state uses waiting")
        expect(StatusPolicy.effectiveState(rawState: "done", age: 0.50) == "done", "completion remains visible during jump")
        expect(StatusPolicy.effectiveState(rawState: "done", age: 0.84) == "idle", "completion expires after jump")
        expect(StatusPolicy.effectiveState(rawState: "thinking", age: 30) == "thinking", "non-completion state remains unchanged")
        expect(StatusPolicy.displayLabel(state: "thinking", storedLabel: "Thinking…") == "Thinking…", "thinking label stays plain")
        expect(StatusPolicy.displayLabel(state: "tool", storedLabel: "Running command") == "Running command", "tool action label is preserved")
        expect(StatusPolicy.displayLabel(state: "tool", storedLabel: "") == "Working…", "missing tool label gets normal fallback")
        expect(HookEventMapper.toolAnimation("apply_patch") == .wave, "editing maps to hand motion")
        expect(HookEventMapper.toolAnimation("read_file") == .review, "reading maps to review")
        expect(HookEventMapper.toolAnimation("search_query") == .review, "search maps to review")
        expect(HookEventMapper.toolAnimation("web__run") == .review, "web work maps to review")
        expect(HookEventMapper.toolAnimation("custom_tool") == .working, "unknown tools map to active work")

        var commandPayload = base
        commandPayload["tool_name"] = "exec_command"
        let firstCommand = HookEventMapper.update(payload: commandPayload, event: "PreToolUse", previous: post, pid: 42, now: now + 5)
        expect(firstCommand?["label"] as? String == "Running command", "command keeps its action label")
        expect(firstCommand?["animation"] as? String == PetAnimation.runRight.rawValue, "first command runs right")
        let afterCommand = HookEventMapper.update(payload: base, event: "PostToolUse", previous: firstCommand, pid: 42, now: now + 6)
        expect(afterCommand?["commandRow"] as? Int == 1, "post-tool preserves command direction")
        let secondCommand = HookEventMapper.update(payload: commandPayload, event: "PreToolUse", previous: afterCommand, pid: 42, now: now + 7)
        expect(secondCommand?["animation"] as? String == PetAnimation.runLeft.rawValue, "second command runs left")
        expect(secondCommand?["commandRow"] as? Int == 2, "command direction is persisted")

        var firstAgentPayload = base
        firstAgentPayload["agent_id"] = "agent-one"
        firstAgentPayload["agent_type"] = "explorer"
        let firstAgent = HookEventMapper.update(payload: firstAgentPayload, event: "SubagentStart", previous: prompt, pid: 42, now: now + 8)
        expect(firstAgent?["state"] as? String == "subagent", "subagent start enters agent state")
        expect(firstAgent?["label"] as? String == "Herding an agent…", "one agent gets funny singular copy")
        expect(firstAgent?["animation"] as? String == PetAnimation.runRight.rawValue, "first agent runs right")
        expect(firstAgent?["activeAgents"] as? [String] == ["agent-one"], "first active agent is persisted")

        var secondAgentPayload = base
        secondAgentPayload["agent_id"] = "agent-two"
        secondAgentPayload["agent_type"] = "reviewer"
        let secondAgent = HookEventMapper.update(payload: secondAgentPayload, event: "SubagentStart", previous: firstAgent, pid: 42, now: now + 9)
        expect(secondAgent?["label"] as? String == "Herding 2 agents…", "multiple agents show their count")
        expect(secondAgent?["animation"] as? String == PetAnimation.runLeft.rawValue, "next agent runs left")

        let oneAgentStopped = HookEventMapper.update(payload: firstAgentPayload, event: "SubagentStop", previous: secondAgent, pid: 42, now: now + 10)
        expect(oneAgentStopped?["state"] as? String == "subagent", "remaining agent keeps agent state")
        expect(oneAgentStopped?["label"] as? String == "Herding an agent…", "remaining agent restores singular copy")
        expect(oneAgentStopped?["activeAgents"] as? [String] == ["agent-two"], "stopped agent is removed")
        let allAgentsStopped = HookEventMapper.update(payload: secondAgentPayload, event: "SubagentStop", previous: oneAgentStopped, pid: 42, now: now + 11)
        expect(allAgentsStopped?["state"] as? String == "thinking", "last agent stop resumes parent thinking")
        expect(allAgentsStopped?["label"] as? String == "Thinking…", "last agent stop restores normal copy")
        expect(allAgentsStopped?["activeAgents"] as? [String] == [], "last active agent is removed")
        expect(StatusPolicy.priority(of: "subagent") > StatusPolicy.priority(of: "idle"), "agent work outranks idle")
        expect(StatusPolicy.isWorking("subagent"), "subagent state renders as active work")
        expect(!StatusPolicy.isWorking("idle"), "idle state does not render as active work")
        expect(HookConfiguration.events.contains("SubagentStart"), "subagent start hook is installed")
        expect(HookConfiguration.events.contains("SubagentStop"), "subagent stop hook is installed")

        let existing = Data("""
        {"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"keep-me"}]}]}}
        """.utf8)
        let installed = try HookConfiguration.install(existing: existing, helperPath: "/Applications/CodexStatusBar.app/Contents/Resources/CodexStatusHook")
        let installedAgain = try HookConfiguration.install(existing: installed, helperPath: "/Applications/CodexStatusBar.app/Contents/Resources/CodexStatusHook")
        let root = try JSONSerialization.jsonObject(with: installedAgain) as! [String: Any]
        let hooks = root["hooks"] as! [String: Any]
        let pre = hooks["PreToolUse"] as! [[String: Any]]
        let commands = pre.flatMap { ($0["hooks"] as? [[String: Any]] ?? []).compactMap { $0["command"] as? String } }
        expect(commands.contains("keep-me"), "install preserves unrelated hooks")
        expect(commands.filter { $0.contains(HookConfiguration.marker) }.count == 1, "reinstall is idempotent")
        expect((hooks["SubagentStart"] as? [[String: Any]])?.count == 1, "subagent start hook installs once")
        expect((hooks["SubagentStop"] as? [[String: Any]])?.count == 1, "subagent stop hook installs once")
        let removed = try HookConfiguration.uninstall(existing: installedAgain)
        let removedText = String(decoding: removed, as: UTF8.self)
        expect(removedText.contains("keep-me"), "uninstall preserves unrelated hook")
        expect(!removedText.contains(HookConfiguration.marker), "uninstall removes marked hooks")

        do {
            _ = try HookConfiguration.install(existing: Data("not json".utf8), helperPath: "/tmp/helper")
            expect(false, "invalid JSON must fail")
        } catch { expect(true, "invalid JSON fails") }

        expect(StatusPolicy.priority(of: "permission") > StatusPolicy.priority(of: "tool"), "permission outranks work")
        expect(StatusPolicy.priority(of: "thinking") > StatusPolicy.priority(of: "idle"), "work outranks idle")
        expect(StatusPolicy.shouldAnimate(userEnabled: true, reduceMotion: false), "animation runs when enabled")
        expect(!StatusPolicy.shouldAnimate(userEnabled: true, reduceMotion: true), "reduced motion disables animation")
        expect(StatusPolicy.versionIsNewer("0.1.10", than: "0.1.9"), "version comparison is numeric")
        let transcript = Data("""
        {"type":"event_msg","payload":{"type":"task_started","turn_id":"turn-1"}}
        {"type":"event_msg","payload":{"type":"turn_aborted","turn_id":"turn-1","reason":"interrupted"}}
        """.utf8)
        expect(StatusPolicy.turnWasAborted(in: transcript, turnID: "turn-1"), "current turn abort is detected")
        expect(!StatusPolicy.turnWasAborted(in: transcript, turnID: "turn-2"), "old turn abort is ignored")
        let config = """
        model = "gpt-5"
        selected-avatar-id = "custom:unckle-stuart"
        """
        expect(PetAssetLocator.selectedPetID(configText: config) == "unckle-stuart", "selected custom pet is parsed")
        let switchedPet = PetAssetLocator.configSelectingPet(
            configText: "model = \"gpt-5\"\nselected-avatar-id = \"custom:old-pet\" # keep me\n",
            petID: "new-pet"
        )
        expect(switchedPet == "model = \"gpt-5\"\nselected-avatar-id = \"custom:new-pet\" # keep me\n", "pet switch preserves config and inline comment")
        expect(PetAssetLocator.configSelectingPet(configText: "model = \"gpt-5\"\n", petID: "new-pet") == "model = \"gpt-5\"\nselected-avatar-id = \"custom:new-pet\"\n", "missing pet setting is appended")
        expect(PetAssetLocator.configSelectingPet(configText: config, petID: "bad\"\nmodel = 'oops'") == nil, "unsafe pet id is rejected")
        let atlas = PetAtlasLayout(width: 1536, height: 1872)
        expect(atlas?.rows == 9, "v1 pet atlas is recognized")
        expect(atlas?.sourceRect(row: 0, column: 0).origin.y == 1664, "idle row crops from atlas top")
        expect(atlas?.sourceRect(row: 7, column: 5).origin.x == 960, "working frame column is located")

        if failures > 0 { exit(1) }
        print("HookCoreTests: \(assertions) passed")
    }
}
