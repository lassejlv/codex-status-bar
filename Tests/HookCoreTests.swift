import Foundation

@main
struct HookCoreTests {
    static var failures = 0

    static func expect(_ condition: @autoclosure () -> Bool, _ message: String) {
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
        expect(prompt?["startedAt"] as? Double == now, "prompt starts timer")
        expect(prompt?["sessionId"] as? String == "thread/../../unsafe", "raw session id remains metadata")
        expect(prompt?["transcript"] as? String == "/tmp/session.jsonl", "session event path is retained")
        expect(HookEventMapper.safeID("thread/../../unsafe") == "thread....unsafe", "unsafe filename characters are removed")

        var toolPayload = base
        toolPayload["tool_name"] = "apply_patch"
        let tool = HookEventMapper.update(payload: toolPayload, event: "PreToolUse", previous: prompt, pid: 42, now: now + 1)
        expect(tool?["state"] as? String == "tool", "pre-tool starts tool state")
        expect(tool?["label"] as? String == "Editing", "apply_patch gets editing label")
        expect(tool?["startedAt"] as? Double == now, "tool preserves turn timer")

        let post = HookEventMapper.update(payload: base, event: "PostToolUse", previous: tool, pid: 42, now: now + 2)
        expect(post?["state"] as? String == "thinking", "post-tool resumes thinking")
        let permission = HookEventMapper.update(payload: toolPayload, event: "PermissionRequest", previous: post, pid: 42, now: now + 3)
        expect(permission?["state"] as? String == "permission", "permission request waits")
        expect(permission?["startedAt"] as? Double == 0, "permission clears timer")
        let stop = HookEventMapper.update(payload: base, event: "Stop", previous: permission, pid: 42, now: now + 4)
        expect(stop?["state"] as? String == "done", "stop completes turn")
        expect(HookEventMapper.update(payload: base, event: "Unknown", previous: nil, pid: 1, now: now) == nil, "unknown event is ignored")

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
        let atlas = PetAtlasLayout(width: 1536, height: 1872)
        expect(atlas?.rows == 9, "v1 pet atlas is recognized")
        expect(atlas?.sourceRect(row: 0, column: 0).origin.y == 1664, "idle row crops from atlas top")
        expect(atlas?.sourceRect(row: 7, column: 5).origin.x == 960, "working frame column is located")

        if failures > 0 { exit(1) }
        print("HookCoreTests: 30 passed")
    }
}
