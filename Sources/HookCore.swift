import Foundation
import CoreGraphics

enum PetAssetLocator {
    static func selectedPetID(configText: String) -> String? {
        for rawLine in configText.split(separator: "\n") {
            let line = rawLine.split(separator: "#", maxSplits: 1).first.map(String.init) ?? ""
            let pair = line.split(separator: "=", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard pair.count == 2, pair[0] == "selected-avatar-id" else { continue }
            let value = pair[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"' "))
            guard value.hasPrefix("custom:") else { return nil }
            let id = String(value.dropFirst("custom:".count))
            return id.isEmpty ? nil : id
        }
        return nil
    }
}

struct PetAtlasLayout {
    let width: Int
    let height: Int
    let columns = 8
    let rows: Int
    let cellWidth: Int
    let cellHeight: Int

    init?(width: Int, height: Int) {
        guard width > 0, width % columns == 0 else { return nil }
        let rows: Int
        switch height {
        case 1872: rows = 9
        case 2288: rows = 11
        default: return nil
        }
        self.width = width
        self.height = height
        self.rows = rows
        self.cellWidth = width / columns
        self.cellHeight = height / rows
        guard cellWidth == 192, cellHeight == 208 else { return nil }
    }

    func sourceRect(row: Int, column: Int) -> CGRect {
        CGRect(x: CGFloat(column * cellWidth),
               y: CGFloat(height - (row + 1) * cellHeight),
               width: CGFloat(cellWidth),
               height: CGFloat(cellHeight))
    }
}

enum PetAnimation: String {
    case idle
    case runRight
    case runLeft
    case wave
    case jump
    case failed
    case waiting
    case working
    case review

    struct Spec {
        let row: Int
        let frameDurationsMilliseconds: [Int]
        let repeats: Bool
    }

    var spec: Spec {
        switch self {
        case .idle:
            return Spec(row: 0, frameDurationsMilliseconds: [280, 110, 110, 140, 140, 320], repeats: true)
        case .runRight:
            return Spec(row: 1, frameDurationsMilliseconds: [120, 120, 120, 120, 120, 120, 120, 220], repeats: true)
        case .runLeft:
            return Spec(row: 2, frameDurationsMilliseconds: [120, 120, 120, 120, 120, 120, 120, 220], repeats: true)
        case .wave:
            return Spec(row: 3, frameDurationsMilliseconds: [140, 140, 140, 280], repeats: true)
        case .jump:
            return Spec(row: 4, frameDurationsMilliseconds: [140, 140, 140, 140, 280], repeats: false)
        case .failed:
            return Spec(row: 5, frameDurationsMilliseconds: [140, 140, 140, 140, 140, 140, 140, 240], repeats: false)
        case .waiting:
            return Spec(row: 6, frameDurationsMilliseconds: [150, 150, 150, 150, 150, 260], repeats: true)
        case .working:
            return Spec(row: 7, frameDurationsMilliseconds: [120, 120, 120, 120, 120, 220], repeats: true)
        case .review:
            return Spec(row: 8, frameDurationsMilliseconds: [150, 150, 150, 150, 150, 280], repeats: true)
        }
    }

    var totalDurationMilliseconds: Int {
        spec.frameDurationsMilliseconds.reduce(0, +)
    }

    func column(atMilliseconds elapsedMilliseconds: Int) -> Int {
        let durations = spec.frameDurationsMilliseconds
        guard !durations.isEmpty else { return 0 }
        let total = totalDurationMilliseconds
        let elapsed = max(0, elapsedMilliseconds)
        let position = spec.repeats ? elapsed % total : min(elapsed, total - 1)
        var boundary = 0
        for (column, duration) in durations.enumerated() {
            boundary += duration
            if position < boundary { return column }
        }
        return durations.count - 1
    }

    static func fallback(state: String, label: String) -> PetAnimation {
        switch state {
        case "idle": return .idle
        case "permission": return .waiting
        case "done": return .jump
        case "failed": return .failed
        case "thinking": return .working
        case "tool":
            switch label {
            case "Running command": return .runRight
            case "Editing": return .wave
            case "Reading", "Searching", "Browsing web": return .review
            default: return .working
            }
        default: return .idle
        }
    }
}

enum StatusPolicy {
    static func priority(of state: String) -> Int {
        switch state {
        case "permission": return 2
        case "thinking", "tool": return 1
        default: return 0
        }
    }

    static func shouldAnimate(userEnabled: Bool, reduceMotion: Bool) -> Bool {
        userEnabled && !reduceMotion
    }

    static func effectiveState(rawState: String, age: Double) -> String {
        guard rawState == "done" else { return rawState }
        let jumpDuration = Double(PetAnimation.jump.totalDurationMilliseconds) / 1000.0
        return age < jumpDuration ? "done" : "idle"
    }

    static func versionIsNewer(_ candidate: String, than current: String) -> Bool {
        let a = candidate.split(separator: ".").map { Int($0) ?? 0 }
        let b = current.split(separator: ".").map { Int($0) ?? 0 }
        for index in 0..<max(a.count, b.count) {
            let left = index < a.count ? a[index] : 0
            let right = index < b.count ? b[index] : 0
            if left != right { return left > right }
        }
        return false
    }

    static func turnWasAborted(in data: Data, turnID: String) -> Bool {
        guard !turnID.isEmpty, let text = String(data: data, encoding: .utf8) else { return false }
        for line in text.split(separator: "\n").reversed() {
            guard let lineData = String(line).data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: lineData) as? [String: Any],
                  object["type"] as? String == "event_msg",
                  let payload = object["payload"] as? [String: Any],
                  payload["turn_id"] as? String == turnID else { continue }
            return payload["type"] as? String == "turn_aborted"
        }
        return false
    }
}

enum HookEventMapper {
    static func safeID(_ value: String?) -> String {
        let raw = value ?? ""
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_.-"))
        let cleaned = String(raw.unicodeScalars.filter { allowed.contains($0) }.prefix(96))
        return cleaned.isEmpty ? "unknown" : cleaned
    }

    static func toolLabel(_ name: String) -> String {
        let lower = name.lowercased()
        if lower == "bash" || lower.contains("exec") || lower.contains("command") { return "Running command" }
        if lower == "apply_patch" || lower.contains("edit") || lower.contains("write") { return "Editing" }
        if lower.contains("read") || lower.contains("fetch") || lower.contains("open") { return "Reading" }
        if lower.contains("search") || lower.contains("find") || lower.contains("grep") || lower.contains("glob") { return "Searching" }
        if lower.contains("browser") || lower.contains("web") { return "Browsing web" }
        return "Using tool"
    }

    static func toolAnimation(_ name: String) -> PetAnimation {
        let lower = name.lowercased()
        if lower == "bash" || lower.contains("exec") || lower.contains("command") { return .runRight }
        if lower == "apply_patch" || lower.contains("edit") || lower.contains("write") { return .wave }
        if lower.contains("read") || lower.contains("fetch") || lower.contains("open") { return .review }
        if lower.contains("search") || lower.contains("find") || lower.contains("grep") || lower.contains("glob") { return .review }
        if lower.contains("browser") || lower.contains("web") { return .review }
        return .working
    }

    static func update(payload: [String: Any], event: String, previous: [String: Any]?, pid: Int32, now: Double) -> [String: Any]? {
        let previous = previous ?? [:]
        let sessionID = payload["session_id"] as? String ?? previous["sessionId"] as? String ?? "unknown"
        let cwd = payload["cwd"] as? String ?? previous["cwd"] as? String ?? ""
        let project = cwd.isEmpty ? (previous["project"] as? String ?? "") : URL(fileURLWithPath: cwd).lastPathComponent
        let tool = payload["tool_name"] as? String ?? ""
        var state: String
        var label: String
        var animation: PetAnimation
        var commandRow = previous["commandRow"] as? Int ?? 2
        var startedAt = previous["startedAt"] as? Double ?? 0
        var started = previous["started"] as? Bool ?? false

        switch event {
        case "SessionStart":
            state = "idle"; label = ""; animation = .idle; startedAt = 0
        case "UserPromptSubmit":
            state = "thinking"; label = "Thinking…"; animation = .working; startedAt = now; started = true
        case "PreToolUse":
            state = "tool"; label = toolLabel(tool); animation = toolAnimation(tool)
            if animation == .runRight {
                commandRow = commandRow == 1 ? 2 : 1
                animation = commandRow == 1 ? .runRight : .runLeft
            }
            startedAt = startedAt == 0 ? now : startedAt; started = true
        case "PostToolUse":
            state = "thinking"; label = "Thinking…"; animation = .working; startedAt = startedAt == 0 ? now : startedAt; started = true
        case "PermissionRequest":
            state = "permission"; label = "Awaiting permission"; animation = .waiting; startedAt = 0; started = true
        case "Stop":
            state = "done"; label = "Done"; animation = .jump; startedAt = 0; started = true
        default:
            return nil
        }

        return [
            "state": state,
            "label": label,
            "animation": animation.rawValue,
            "commandRow": commandRow,
            "tool": tool,
            "project": project,
            "cwd": cwd,
            "sessionId": sessionID,
            "turnId": payload["turn_id"] as? String ?? previous["turnId"] as? String ?? "",
            "transcript": payload["transcript_path"] as? String ?? previous["transcript"] as? String ?? "",
            "model": payload["model"] as? String ?? previous["model"] as? String ?? "",
            "surface": payload["surface"] as? String ?? previous["surface"] as? String ?? "",
            "term_program": payload["term_program"] as? String ?? previous["term_program"] as? String ?? "",
            "pid": Int(pid),
            "started": started,
            "startedAt": startedAt,
            "ts": now,
        ]
    }
}

enum HookConfiguration {
    static let marker = "codex-status-bar-hook"
    static let events = ["SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse", "PermissionRequest", "Stop"]

    static func command(helperPath: String, event: String) -> String {
        let quoted = "'" + helperPath.replacingOccurrences(of: "'", with: "'\\''") + "'"
        return "\(quoted) \(event) # \(marker)"
    }

    static func decode(_ data: Data?) throws -> [String: Any] {
        guard let data, !data.isEmpty else { return [:] }
        guard let root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw NSError(domain: "CodexStatusBar", code: 1, userInfo: [NSLocalizedDescriptionKey: "hooks.json must contain a JSON object"])
        }
        return root
    }

    static func encoded(_ root: [String: Any]) throws -> Data {
        var data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
        data.append(0x0A)
        return data
    }

    static func uninstallObject(_ root: [String: Any]) -> [String: Any] {
        var root = root
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        for event in Array(hooks.keys) {
            guard let groups = hooks[event] as? [[String: Any]] else { continue }
            let keptGroups: [[String: Any]] = groups.compactMap { group in
                var group = group
                let handlers = (group["hooks"] as? [[String: Any]] ?? []).filter {
                    !(($0["command"] as? String) ?? "").contains(marker)
                }
                guard !handlers.isEmpty else { return nil }
                group["hooks"] = handlers
                return group
            }
            if keptGroups.isEmpty { hooks.removeValue(forKey: event) } else { hooks[event] = keptGroups }
        }
        if hooks.isEmpty { root.removeValue(forKey: "hooks") } else { root["hooks"] = hooks }
        return root
    }

    static func install(existing: Data?, helperPath: String) throws -> Data {
        var root = uninstallObject(try decode(existing))
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        for event in events {
            var groups = hooks[event] as? [[String: Any]] ?? []
            var group: [String: Any] = [
                "hooks": [["type": "command", "command": command(helperPath: helperPath, event: event), "timeout": 5]],
            ]
            if event == "SessionStart" { group["matcher"] = "startup|resume|clear|compact" }
            if ["PreToolUse", "PostToolUse", "PermissionRequest"].contains(event) { group["matcher"] = "*" }
            groups.append(group)
            hooks[event] = groups
        }
        root["hooks"] = hooks
        return try encoded(root)
    }

    static func uninstall(existing: Data?) throws -> Data {
        try encoded(uninstallObject(try decode(existing)))
    }
}
