import Foundation

/// The subset of yabai's configuration the app exposes for live editing.
struct LiveSettings: Equatable {
    enum Layout: String, CaseIterable, Identifiable {
        case bsp, monocle, float
        var id: String { rawValue }
        var label: String {
            switch self {
            case .bsp: return "BSP"
            case .monocle: return "Monocle"
            case .float: return "Flottant"
            }
        }
    }

    enum Placement: String, CaseIterable, Identifiable {
        case firstChild = "first_child"
        case secondChild = "second_child"
        var id: String { rawValue }
        var label: String {
            switch self {
            case .firstChild: return "Premier enfant"
            case .secondChild: return "Deuxième enfant"
            }
        }
    }

    var layout: Layout = .bsp
    var windowGap: Int = 10
    var topPadding: Int = 10
    var bottomPadding: Int = 10
    var leftPadding: Int = 10
    var rightPadding: Int = 10
    var windowPlacement: Placement = .secondChild

    /// Keys understood by `yabai -m config`.
    var configPairs: [(key: String, value: String)] {
        [
            ("layout", layout.rawValue),
            ("window_gap", String(windowGap)),
            ("top_padding", String(topPadding)),
            ("bottom_padding", String(bottomPadding)),
            ("left_padding", String(leftPadding)),
            ("right_padding", String(rightPadding)),
            ("window_placement", windowPlacement.rawValue)
        ]
    }
}

/// A snapshot of everything the app knows about the yabai installation.
struct YabaiSnapshot: Equatable {
    var isInstalled = false
    var isRunning = false
    var version = "—"
    var serviceInstalled = false
    var serviceLoaded = false
    var spaceCount = 0
    var windowCount = 0
    var skhdInstalled = false
    var skhdRunning = false
}
