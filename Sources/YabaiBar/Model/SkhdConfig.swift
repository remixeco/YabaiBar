import Foundation

/// A modifier key understood by skhd.
enum SkhdModifier: String, CaseIterable, Identifiable, Hashable {
    case fn, ctrl, alt, shift, cmd

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .fn: return "fn"
        case .ctrl: return "⌃"
        case .alt: return "⌥"
        case .shift: return "⇧"
        case .cmd: return "⌘"
        }
    }

    /// Canonical order used when a combination is written back to disk.
    static let order: [SkhdModifier] = [.fn, .ctrl, .alt, .shift, .cmd]
}

/// One key combination bound to one command.
struct SkhdBinding: Identifiable, Equatable, Hashable {
    var id = UUID()
    var modifiers: [SkhdModifier] = []
    var key: String = ""
    var action: String = ""
    /// Restricts the binding to a list of applications.
    var applications: [String] = []
    /// Restricts the binding to a skhd mode.
    var mode: String?
    /// When false, the key press is forwarded to the application (`->`).
    var consumesKey: Bool = true

    /// Human readable combination, e.g. "⇧⌥H".
    var display: String {
        let symbols = SkhdModifier.order
            .filter { modifiers.contains($0) }
            .map(\.symbol)
            .joined()
        let letter = key.uppercased()
        return symbols + letter
    }

    /// The combination as skhd writes it, e.g. "shift + alt - h".
    var keysym: String {
        var parts: [String] = []
        for modifier in SkhdModifier.order where modifiers.contains(modifier) {
            parts.append(modifier.rawValue)
        }
        let combo = parts.isEmpty ? key : parts.joined(separator: " + ") + " - " + key
        return combo
    }

    /// The full line as skhd expects it.
    var line: String {
        var text = keysym
        if !consumesKey { text += " ->" }
        if !applications.isEmpty {
            text += " [" + applications.joined(separator: ", ") + "]"
        }
        if let mode, !mode.isEmpty {
            text += " ; " + mode
        }
        return text + " : " + action
    }
}

/// A line of an `skhdrc` file: a comment, a mode declaration or a binding.
enum SkhdItem: Identifiable {
    case comment(String)
    case blank
    case mode(name: String, command: String)
    case binding(SkhdBinding)

    var id: String {
        switch self {
        case .comment(let text): return "c:" + text
        case .blank: return "b:" + UUID().uuidString
        case .mode(let name, _): return "m:" + name
        case .binding(let binding): return "k:" + binding.id.uuidString
        }
    }
}

/// Parses and serialises the `skhdrc` script.
enum SkhdConfig {

    // MARK: - Locating the file

    /// Where skhd looks for its configuration, in the order it searches.
    static func configFile() -> String {
        if let xdg = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"], !xdg.isEmpty {
            let candidate = xdg + "/skhd/skhdrc"
            if FileManager.default.fileExists(atPath: candidate) { return candidate }
        }
        let standard = Paths.home + "/.config/skhd/skhdrc"
        if FileManager.default.fileExists(atPath: standard) { return standard }
        let legacy = Paths.home + "/.skhdrc"
        if FileManager.default.fileExists(atPath: legacy) { return legacy }
        return standard
    }

    static func exists() -> Bool {
        FileManager.default.fileExists(atPath: configFile())
    }

    static func contents() -> String {
        guard let data = FileManager.default.contents(atPath: configFile()),
              let text = String(data: data, encoding: .utf8) else {
            return ""
        }
        return text
    }

    static func write(_ text: String) throws {
        let url = URL(fileURLWithPath: configFile())
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - Parsing

    /// Splits the file into an ordered list of items, preserving comments.
    static func parse(_ text: String) -> [SkhdItem] {
        text.components(separatedBy: "\n").map { rawLine in
            let line = rawLine.trimmingCharacters(in: .whitespaces)

            if line.isEmpty { return .blank }
            if line.hasPrefix("#") { return .comment(line) }
            if line.hasPrefix("::") { return parseMode(line) ?? .comment(line) }
            if let binding = parseBinding(line) { return .binding(binding) }
            return .comment(line)
        }
    }

    /// Parses a mode declaration: `:: name @ : command`.
    private static func parseMode(_ line: String) -> SkhdItem? {
        var body = String(line.dropFirst(2)).trimmingCharacters(in: .whitespaces)
        if body.hasPrefix("@") {
            body = String(body.dropFirst()).trimmingCharacters(in: .whitespaces)
        }
        guard let separator = body.firstIndex(of: ":") else {
            return .mode(name: body, command: "")
        }
        let name = String(body[body.startIndex..<separator]).trimmingCharacters(in: .whitespaces)
        let command = String(body[body.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
        return .mode(name: name, command: command)
    }

    /// Parses a binding line such as `shift + alt - h [Safari] ; tiling : yabai -m window --focus west`.
    static func parseBinding(_ line: String) -> SkhdBinding? {
        guard let separator = firstColonOutsideBrackets(line) else { return nil }

        var left = String(line[line.startIndex..<separator]).trimmingCharacters(in: .whitespaces)
        let action = String(line[line.index(after: separator)...]).trimmingCharacters(in: .whitespaces)
        guard !action.isEmpty else { return nil }

        // Application scope.
        var applications: [String] = []
        if let open = left.firstIndex(of: "["), let close = left[open...].firstIndex(of: "]") {
            let list = String(left[left.index(after: open)..<close])
            applications = list.split(separator: ",").map {
                $0.trimmingCharacters(in: .whitespaces)
            }.filter { !$0.isEmpty }
            left = String(left[line.startIndex..<open]) + String(left[left.index(after: close)...])
        }

        // Mode scope.
        var mode: String?
        if let semicolon = left.firstIndex(of: ";") {
            let rest = String(left[left.index(after: semicolon)...])
                .trimmingCharacters(in: .whitespaces)
            // The mode name ends at the first space.
            if let space = rest.firstIndex(of: " ") {
                mode = String(rest[rest.startIndex..<space])
                left = String(left[line.startIndex..<semicolon]).trimmingCharacters(in: .whitespaces)
            } else {
                mode = rest
                left = String(left[line.startIndex..<semicolon]).trimmingCharacters(in: .whitespaces)
            }
        }

        // Key consumption marker.
        var consumesKey = true
        if let arrow = left.range(of: "->") {
            consumesKey = false
            left = String(left[line.startIndex..<arrow.lowerBound]) + String(left[arrow.upperBound...])
            left = left.trimmingCharacters(in: .whitespaces)
        }

        // The keysym itself: `mod + mod - key`.
        guard let dash = left.lastIndex(of: "-"), dash > left.startIndex else { return nil }
        let modifierPart = String(left[left.startIndex..<dash]).trimmingCharacters(in: .whitespaces)
        let key = String(left[left.index(after: dash)...]).trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else { return nil }

        var modifiers: [SkhdModifier] = []
        for token in modifierPart.split(separator: "+") {
            let name = token.trimmingCharacters(in: .whitespaces).lowercased()
            if let modifier = SkhdModifier(rawValue: name), !modifiers.contains(modifier) {
                modifiers.append(modifier)
            }
        }

        return SkhdBinding(
            modifiers: modifiers,
            key: key,
            action: action,
            applications: applications,
            mode: mode,
            consumesKey: consumesKey
        )
    }

    /// Finds the first colon that is not inside an application scope.
    private static func firstColonOutsideBrackets(_ line: String) -> String.Index? {
        var depth = 0
        var index = line.startIndex
        while index < line.endIndex {
            let character = line[index]
            if character == "[" { depth += 1 }
            if character == "]" { depth -= 1 }
            if character == ":" && depth == 0 { return index }
            index = line.index(after: index)
        }
        return nil
    }

    // MARK: - Serialising

    /// Renders items back into a script.
    static func serialize(_ items: [SkhdItem]) -> String {
        var lines: [String] = []
        for item in items {
            switch item {
            case .comment(let text): lines.append(text)
            case .blank: lines.append("")
            case .mode(let name, let command):
                lines.append(command.isEmpty ? ":: \(name)" : ":: \(name) @ : \(command)")
            case .binding(let binding): lines.append(binding.line)
            }
        }
        return lines.joined(separator: "\n")
    }

    /// Every mode declared in the file.
    static func modes(in items: [SkhdItem]) -> [String] {
        var names: [String] = []
        for item in items {
            if case .mode(let name, _) = item, !names.contains(name) {
                names.append(name)
            }
        }
        return names
    }
}
