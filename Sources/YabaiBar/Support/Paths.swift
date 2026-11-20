import Foundation

/// Well-known filesystem locations used by yabai.
enum Paths {
    static var home: String { NSHomeDirectory() }
    static var user: String { NSUserName() }

    /// The yabai binary, when Homebrew has it installed.
    static var yabaiBinary: String? {
        Shell.which("yabai")
    }

    /// The skhd binary, when Homebrew has it installed.
    static var skhdBinary: String? {
        Shell.which("skhd")
    }

    /// The configuration file yabai actually reads.
    ///
    /// yabai resolves it in this order: `$XDG_CONFIG_HOME/yabai/yabairc`,
    /// `~/.config/yabai/yabairc`, then `~/.yabairc`.
    static var yabaiConfigFile: String {
        if let xdg = ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"], !xdg.isEmpty {
            let candidate = xdg + "/yabai/yabairc"
            if FileManager.default.fileExists(atPath: candidate) { return candidate }
        }
        let standard = home + "/.config/yabai/yabairc"
        if FileManager.default.fileExists(atPath: standard) { return standard }
        let legacy = home + "/.yabairc"
        if FileManager.default.fileExists(atPath: legacy) { return legacy }
        // Nothing on disk yet: point at the canonical location so the app can
        // create it there.
        return standard
    }

    /// The launchd agent yabai installs to survive logins.
    static var yabaiLaunchAgent: String {
        home + "/Library/LaunchAgents/com.asmvik.yabai.plist"
    }

    static var skhdLaunchAgent: String {
        home + "/Library/LaunchAgents/com.koekeishiya.skhd.plist"
    }

    static var yabaiStdoutLog: String { "/tmp/yabai_\(user).out.log" }
    static var yabaiStderrLog: String { "/tmp/yabai_\(user).err.log" }
    static var skhdStdoutLog: String { "/tmp/skhd_\(user).out.log" }
    static var skhdStderrLog: String { "/tmp/skhd_\(user).err.log" }
}
