import Foundation

/// Reads and edits the `yabairc` shell script yabai sources at startup.
struct ConfigFile {

    static func contents() -> String {
        guard let data = FileManager.default.contents(atPath: Paths.yabaiConfigFile),
              let text = String(data: data, encoding: .utf8) else {
            return ""
        }
        return text
    }

    static func write(_ text: String) throws {
        let url = URL(fileURLWithPath: Paths.yabaiConfigFile)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    /// Rewrites `yabai -m config <key> <value>` lines so they match `settings`.
    ///
    /// Existing lines are updated in place, preserving comments and formatting.
    /// Missing keys are appended in a sensible order at the end of the file.
    func apply(settings: LiveSettings) throws -> String {
        var text = Self.contents()
        if text.isEmpty {
            text = "#!/usr/bin/env sh\n\n"
        }

        for (key, value) in settings.configPairs {
            text = replaceSetting(key: key, value: value, in: text)
        }

        try Self.write(text)
        return text
    }

    /// Rewrites a single `yabai -m config` assignment, appending it when absent.
    private func replaceSetting(key: String, value: String, in text: String) -> String {
        var lines = text.components(separatedBy: "\n")
        let pattern = try? NSRegularExpression(
            pattern: "^(\\s*yabai\\s+-m\\s+config\\s+" + NSRegularExpression.escapedPattern(for: key) + ")\\s+\\S+.*$"
        )

        var replaced = false
        if let pattern {
            for index in lines.indices {
                let range = NSRange(lines[index].startIndex..., in: lines[index])
                guard let match = pattern.firstMatch(in: lines[index], range: range) else { continue }
                if let prefixRange = Range(match.range(at: 1), in: lines[index]) {
                    lines[index] = String(lines[index][prefixRange]) + " " + value
                    replaced = true
                    break
                }
            }
        }

        if !replaced {
            // Keep the script valid and append the new setting.
            while let last = lines.last, last.trimmingCharacters(in: .whitespaces).isEmpty {
                lines.removeLast()
            }
            lines.append("yabai -m config \(key) \(value)")
            lines.append("")
        }

        return lines.joined(separator: "\n")
    }
}
