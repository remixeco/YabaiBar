import Foundation
import ServiceManagement

/// User preferences, persisted in `UserDefaults`.
@MainActor
final class AppSettings: ObservableObject {

    private enum Key {
        static let launchAtLogin = "launchAtLogin"
        static let startYabaiOnLaunch = "startYabaiOnLaunch"
        static let confirmStop = "confirmStop"
        static let liveSettings = "liveSettings"
        static let lastUpdateCheck = "lastUpdateCheck"
    }

    private let defaults = UserDefaults.standard

    /// Launch the app itself when the user logs in.
    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Key.launchAtLogin) }
    }

    /// Start the yabai service as soon as the app opens.
    @Published var startYabaiOnLaunch: Bool {
        didSet { defaults.set(startYabaiOnLaunch, forKey: Key.startYabaiOnLaunch) }
    }

    /// Ask for confirmation before stopping yabai.
    @Published var confirmStop: Bool {
        didSet { defaults.set(confirmStop, forKey: Key.confirmStop) }
    }

    /// Last time an update check ran.
    @Published var lastUpdateCheck: Date? {
        didSet { defaults.set(lastUpdateCheck, forKey: Key.lastUpdateCheck) }
    }

    init() {
        launchAtLogin = defaults.bool(forKey: Key.launchAtLogin)
        startYabaiOnLaunch = defaults.object(forKey: Key.startYabaiOnLaunch) as? Bool ?? true
        confirmStop = defaults.object(forKey: Key.confirmStop) as? Bool ?? false
        lastUpdateCheck = defaults.object(forKey: Key.lastUpdateCheck) as? Date
    }

    /// Applies the "launch at login" preference to the system.
    ///
    /// `SMAppService` is the modern way, but it refuses ad-hoc signed builds.
    /// A hand-written launch agent covers that case.
    func syncLoginItem() {
        let service = SMAppService.mainApp
        let enabled = service.status == .enabled

        if launchAtLogin, !enabled {
            try? service.register()
        } else if !launchAtLogin, enabled {
            try? service.unregister()
        }

        if launchAtLogin {
            if service.status != .enabled {
                LoginItem.installFallback()
            }
        } else {
            LoginItem.removeFallback()
        }
    }
}

/// A launch agent used when `SMAppService` cannot register the app itself.
enum LoginItem {
    static var plistPath: String {
        Paths.home + "/Library/LaunchAgents/com.yabaibar.yabaibar.plist"
    }

    static var label: String { "com.yabaibar.yabaibar" }

    static func installFallback() {
        let bundlePath = Bundle.main.bundlePath
        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": [bundlePath + "/Contents/MacOS/YabaiBar"],
            "RunAtLoad": true,
            "KeepAlive": false
        ]
        guard let data = try? PropertyListSerialization.data(
            fromPropertyList: plist, format: .xml, options: 0
        ) else { return }

        let url = URL(fileURLWithPath: plistPath)
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true
        )
        try? data.write(to: url)
        try? FileManager.default.setAttributes(
            [.posixPermissions: 0o644], ofItemAtPath: plistPath
        )

        // load it right away instead of waiting for the next login
        let uid = getuid()
        Shell.runSync("/bin/launchctl", ["bootstrap", "gui/\(uid)", plistPath])
    }

    static func removeFallback() {
        let uid = getuid()
        Shell.runSync("/bin/launchctl", ["bootout", "gui/\(uid)/\(label)"])
        try? FileManager.default.removeItem(atPath: plistPath)
    }
}
