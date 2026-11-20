import AppKit
import SwiftUI

/// Captures the next key combination and reports it in skhd syntax.
struct KeyRecorder: NSViewRepresentable {
    @Binding var modifiers: [SkhdModifier]
    @Binding var key: String
    /// Called with the captured combination.
    var onCapture: (([SkhdModifier], String) -> Void)?

    func makeNSView(context: Context) -> KeyRecorderView {
        let view = KeyRecorderView()
        view.onCapture = onCapture
        view.apply(modifiers: modifiers, key: key)
        return view
    }

    func updateNSView(_ nsView: KeyRecorderView, context: Context) {
        nsView.onCapture = onCapture
        nsView.apply(modifiers: modifiers, key: key)
    }

    /// The AppKit view that listens for key presses.
    ///
    /// It draws nothing: the label is rendered by SwiftUI underneath, so the
    /// view only has to capture keystrokes.
    final class KeyRecorderView: NSView {
        var onCapture: (([SkhdModifier], String) -> Void)?
        private var modifiers: [SkhdModifier] = []
        private var key: String = ""

        override var acceptsFirstResponder: Bool { true }
        override var isOpaque: Bool { false }

        func apply(modifiers: [SkhdModifier], key: String) {
            self.modifiers = modifiers
            self.key = key
        }

        override func mouseDown(with event: NSEvent) {
            window?.makeFirstResponder(self)
        }

        override func keyDown(with event: NSEvent) {
            let capturedModifiers = Self.modifiers(from: event)
            guard let capturedKey = Self.keyName(from: event) else {
                NSSound.beep()
                return
            }
            modifiers = capturedModifiers
            key = capturedKey
            needsDisplay = true
            onCapture?(capturedModifiers, capturedKey)
        }

        override func performKeyEquivalent(with event: NSEvent) -> Bool {
            keyDown(with: event)
            return true
        }

        // MARK: - Translation

        static func modifiers(from event: NSEvent) -> [SkhdModifier] {
            let flags = event.modifierFlags
            var result: [SkhdModifier] = []
            if flags.contains(.function) { result.append(.fn) }
            if flags.contains(.control) { result.append(.ctrl) }
            if flags.contains(.option) { result.append(.alt) }
            if flags.contains(.shift) { result.append(.shift) }
            if flags.contains(.command) { result.append(.cmd) }
            return result
        }

        /// Maps an event onto a key name skhd understands.
        static func keyName(from event: NSEvent) -> String? {
            if let name = namedKeys[Int(event.keyCode)] { return name }

            guard let characters = event.charactersIgnoringModifiers,
                  characters.count == 1 else { return nil }

            let character = characters
            if let scalar = character.unicodeScalars.first {
                switch CharacterSet.alphanumerics.contains(scalar) {
                case true:
                    return String(character).lowercased()
                case false:
                    return String(character)
                }
            }
            return nil
        }

        /// Special keys, by their macOS virtual key code.
        private static let namedKeys: [Int: String] = [
            36: "return",
            48: "tab",
            49: "space",
            51: "backspace",
            53: "escape",
            65: "keypad_decimal",
            67: "keypad_multiply",
            69: "keypad_plus",
            71: "keypad_clear",
            75: "keypad_divide",
            76: "return",
            78: "keypad_minus",
            81: "keypad_equals",
            82: "keypad_0",
            83: "keypad_1",
            84: "keypad_2",
            85: "keypad_3",
            86: "keypad_4",
            87: "keypad_5",
            88: "keypad_6",
            89: "keypad_7",
            91: "keypad_8",
            92: "keypad_9",
            114: "insert",
            115: "home",
            116: "pageup",
            117: "pagedown",
            119: "end",
            121: "delete",
            123: "left",
            124: "right",
            125: "down",
            126: "up",
            122: "f1",
            120: "f2",
            99: "f3",
            118: "f4",
            96: "f5",
            97: "f6",
            98: "f7",
            100: "f8",
            101: "f9",
            109: "f10",
            103: "f11",
            111: "f12",
            105: "f13",
            107: "f14",
            113: "f15",
            106: "f16",
            64: "f17",
            79: "f18",
            80: "f19",
            90: "f20"
        ]
    }
}
