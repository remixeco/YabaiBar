import Foundation

/// Wraps the yabai command line tool and its launchd service.
struct YabaiService {

    // MARK: - Probing

    /// Reads the current state of the installation.
    func probe() async -> YabaiSnapshot {
        var snapshot = YabaiSnapshot()

        let binary = Paths.yabaiBinary
        snapshot.isInstalled = binary != nil
        snapshot.serviceInstalled = FileManager.default.fileExists(atPath: Paths.yabaiLaunchAgent)

        guard let binary else {
            snapshot.skhdInstalled = Paths.skhdBinary != nil
            return snapshot
        }

        // `yabai -m query --spaces` only answers when the daemon is up, which makes
        // it a reliable "is it running?" probe.
        let spaces = await Shell.run(binary, ["-m", "query", "--spaces"])
        snapshot.isRunning = spaces.succeeded && spaces.output.contains("\"uuid\"")

        if snapshot.isRunning {
            let windows = await Shell.run(binary, ["-m", "query", "--windows"])
            snapshot.spaceCount = countOccurrences(of: "\"uuid\"", in: spaces.output)
            snapshot.windowCount = countOccurrences(of: "\"id\"", in: windows.output)
        }

        let version = await Shell.run(binary, ["--version"])
        if version.succeeded {
            let raw = version.output
            snapshot.version = raw.replacingOccurrences(of: "yabai-v", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if snapshot.version.isEmpty { snapshot.version = "—" }
        }

        snapshot.serviceLoaded = await isServiceLoaded(label: "com.asmvik.yabai")

        snapshot.skhdInstalled = Paths.skhdBinary != nil
        if snapshot.skhdInstalled {
            snapshot.skhdRunning = await isServiceLoaded(label: "com.koekeishiya.skhd")
        }

        return snapshot
    }

    /// Queries launchd for a service in the user's GUI domain.
    func isServiceLoaded(label: String) async -> Bool {
        let uid = getuid()
        let result = await Shell.run("/bin/launchctl", ["print", "gui/\(uid)/\(label)"])
        return result.succeeded
    }

    // MARK: - Service control

    func start() async -> CommandResult {
        await runService("--start-service")
    }

    func stop() async -> CommandResult {
        await runService("--stop-service")
    }

    func restart() async -> CommandResult {
        await runService("--restart-service")
    }

    func installService() async -> CommandResult {
        await runService("--install-service")
    }

    func uninstallService() async -> CommandResult {
        await runService("--uninstall-service")
    }

    private func runService(_ flag: String) async -> CommandResult {
        guard let binary = Paths.yabaiBinary else {
            return CommandResult(status: -1, stdout: "", stderr: "yabai n'est pas installé.")
        }
        return await Shell.run(binary, [flag])
    }

    // MARK: - skhd

    func startSkhd() async -> CommandResult {
        await runSkhdService("--start-service")
    }

    func stopSkhd() async -> CommandResult {
        await runSkhdService("--stop-service")
    }

    func restartSkhd() async -> CommandResult {
        await runSkhdService("--restart-service")
    }

    func installSkhdService() async -> CommandResult {
        await runSkhdService("--install-service")
    }

    private func runSkhdService(_ flag: String) async -> CommandResult {
        guard let binary = Paths.skhdBinary else {
            return CommandResult(status: -1, stdout: "", stderr: "skhd n'est pas installé.")
        }
        return await Shell.run(binary, [flag])
    }

    // MARK: - Configuration

    /// Reads a single yabai setting, e.g. `window_gap`.
    func configValue(_ key: String) async -> String? {
        guard let binary = Paths.yabaiBinary else { return nil }
        let result = await Shell.run(binary, ["-m", "config", key])
        guard result.succeeded else { return nil }
        let value = result.output
        return value.isEmpty ? nil : value
    }

    /// Applies a single yabai setting to the running instance.
    func setConfig(key: String, value: String) async -> CommandResult {
        guard let binary = Paths.yabaiBinary else {
            return CommandResult(status: -1, stdout: "", stderr: "yabai n'est pas installé.")
        }
        return await Shell.run(binary, ["-m", "config", key, value])
    }

    /// Reads the current live settings so the UI can mirror them.
    func readLiveSettings() async -> LiveSettings {
        var settings = LiveSettings()
        guard let binary = Paths.yabaiBinary else { return settings }

        let keys = [
            "layout", "window_gap", "top_padding", "bottom_padding",
            "left_padding", "right_padding", "window_placement"
        ]
        for key in keys {
            let result = await Shell.run(binary, ["-m", "config", key])
            guard result.succeeded else { continue }
            let value = result.output
            switch key {
            case "layout":
                if let layout = LiveSettings.Layout(rawValue: value) { settings.layout = layout }
            case "window_gap":
                settings.windowGap = Int(value) ?? settings.windowGap
            case "top_padding":
                settings.topPadding = Int(value) ?? settings.topPadding
            case "bottom_padding":
                settings.bottomPadding = Int(value) ?? settings.bottomPadding
            case "left_padding":
                settings.leftPadding = Int(value) ?? settings.leftPadding
            case "right_padding":
                settings.rightPadding = Int(value) ?? settings.rightPadding
            case "window_placement":
                if let placement = LiveSettings.Placement(rawValue: value) {
                    settings.windowPlacement = placement
                }
            default:
                break
            }
        }
        return settings
    }

    // MARK: - Helpers

    private func countOccurrences(of needle: String, in haystack: String) -> Int {
        guard !haystack.isEmpty else { return 0 }
        var count = 0
        var index = haystack.startIndex
        while let range = haystack.range(of: needle, range: index..<haystack.endIndex) {
            count += 1
            index = range.upperBound
        }
        return count
    }
}
