import AppKit
import Combine
import SwiftUI

/// Owns the yabai controller and the dashboard window.
///
/// YabaiBar is an accessory app: it lives in the menu bar and has no Dock
/// icon. The dashboard is an ordinary window, shown on demand.
@MainActor
final class AppEnvironment: ObservableObject {

    let controller = YabaiController()

    private var dashboardWindow: NSWindow?
    private var cancellables: Set<AnyCancellable> = []

    init() {
        // Forward the controller's changes so that views observing the
        // environment (the menu bar label, for one) refresh with it.
        controller.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)

        controller.bootstrap()
    }

    /// Brings the dashboard to the front, creating it the first time.
    func showDashboard() {
        if let dashboardWindow {
            NSApp.activate(ignoringOtherApps: true)
            dashboardWindow.makeKeyAndOrderFront(nil)
            return
        }

        let hosting = NSHostingController(
            rootView: DashboardView().environmentObject(controller)
        )
        let window = NSWindow(contentViewController: hosting)
        window.title = "YabaiBar"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.setContentSize(NSSize(width: 700, height: 760))
        window.minSize = NSSize(width: 660, height: 520)
        window.isReleasedWhenClosed = false
        window.tabbingMode = .disallowed

        let autosaveKey = "NSWindow Frame YabaiBarDashboard"
        window.setFrameAutosaveName(autosaveKey)
        if UserDefaults.standard.string(forKey: autosaveKey) == nil {
            window.center()
        }

        dashboardWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    /// Shows the standard macOS "About" panel.
    func showAbout() {
        NSApp.activate(ignoringOtherApps: true)
        var options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: "YabaiBar",
            .init(rawValue: "Copyright"): "YabaiBar — gestion graphique de yabai et skhd."
        ]
        if let icon = NSApp.applicationIconImage {
            options[.applicationIcon] = icon
        }
        NSApp.orderFrontStandardAboutPanel(options: options)
    }
}
