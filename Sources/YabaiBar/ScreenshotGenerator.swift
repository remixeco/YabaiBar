import AppKit
import SwiftUI

/// Renders the app's views to PNG files, without touching the screen.
///
/// Used to regenerate the images in `docs/` and in the README:
///
///     /Applications/YabaiBar.app/Contents/MacOS/YabaiBar --screenshots docs
///
/// The views are hosted in an off-screen `NSHostingView` and captured with
/// `cacheDisplay`, so the result is exactly what the user sees — including
/// AppKit-backed subviews — at the display's backing scale.
enum ScreenshotGenerator {

    /// Returns the output directory when the app was launched in screenshot mode.
    static func outputDirectory() -> String? {
        let arguments = CommandLine.arguments
        guard let index = arguments.firstIndex(of: "--screenshots") else { return nil }
        let next = index + 1
        if next < arguments.count, !arguments[next].hasPrefix("--") {
            return arguments[next]
        }
        return "docs"
    }

    @MainActor
    static func run(into directory: String) async {
        let environment = AppEnvironment()
        let controller = environment.controller
        await controller.refresh()
        await controller.loadLiveSettings()
        controller.loadShortcuts()

        let manager = FileManager.default
        try? manager.createDirectory(
            at: URL(fileURLWithPath: directory), withIntermediateDirectories: true
        )

        print("appearance: \(NSApp.effectiveAppearance.name.rawValue)")

        // The menu bar panel. The real panel sits on a translucent system
        // material that does not exist off-screen, so the backdrop is painted
        // explicitly — otherwise the light-on-dark text would be invisible.
        if let image = snapshot(
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                MenuBarPanel()
                    .environmentObject(environment)
                    .environmentObject(controller)
            }
            .frame(width: 300),
            size: NSSize(width: 300, height: 470),
            fitToContent: true
        ) {
            write(image, to: directory, name: "menubar-panel")
        }

        // The dashboard.
        if let image = snapshot(
            DashboardView().environmentObject(controller),
            size: NSSize(width: 700, height: 790)
        ) {
            write(image, to: directory, name: "dashboard")
        }

        // The shortcut editor on its own.
        if let image = snapshot(
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                ShortcutsView()
                    .environmentObject(controller)
            }
            .frame(width: 700, height: 620, alignment: .top)
            .clipped(),
            size: NSSize(width: 700, height: 620)
        ) {
            write(image, to: directory, name: "shortcuts")
        }

        // The application icon.
        if let image = snapshot(
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 220, height: 220),
            size: NSSize(width: 220, height: 220)
        ) {
            write(image, to: directory, name: "icon")
        }
    }

    // MARK: - Rendering

    @MainActor
    private static func snapshot<V: View>(
        _ view: V,
        size: NSSize,
        fitToContent: Bool = false
    ) -> NSBitmapImageRep? {
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: size)

        // A hosting window gives SwiftUI a real window to lay out in, and
        // inherits the system appearance so the shots match what users see.
        let window = NSWindow(
            contentRect: hosting.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.appearance = NSApp.effectiveAppearance
        window.contentView = hosting
        window.setContentSize(size)
        window.makeKeyAndOrderFront(nil)

        // SwiftUI lays out and renders asynchronously: give it several passes.
        for _ in 0..<12 {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
            hosting.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
        }

        // Shrink the window onto the content it actually occupies, so the
        // shot has no empty margins.
        let fitting = hosting.fittingSize
        if fitToContent, fitting.height > 0, fitting.width > 0 {
            window.setContentSize(fitting)
            hosting.frame = NSRect(origin: .zero, size: fitting)
            for _ in 0..<6 {
                RunLoop.main.run(until: Date().addingTimeInterval(0.04))
                hosting.layoutSubtreeIfNeeded()
                window.displayIfNeeded()
            }
        }

        let bounds = hosting.bounds
        guard bounds.width > 0, bounds.height > 0,
              let representation = hosting.bitmapImageRepForCachingDisplay(in: bounds) else {
            window.orderOut(nil)
            return nil
        }
        hosting.cacheDisplay(in: bounds, to: representation)

        window.orderOut(nil)
        return representation
    }

    private static func write(_ representation: NSBitmapImageRep, to directory: String, name: String) {
        guard let png = representation.representation(using: .png, properties: [:]) else { return }
        let url = URL(fileURLWithPath: directory).appendingPathComponent("\(name).png")
        try? png.write(to: url)
        print("wrote \(url.path)")
    }
}
