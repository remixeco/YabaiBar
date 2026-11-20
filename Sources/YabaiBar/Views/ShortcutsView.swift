import SwiftUI

/// The shortcut editor: a structured list plus a raw text mode.
struct ShortcutsView: View {
    @EnvironmentObject private var controller: YabaiController

    var body: some View {
        if !controller.snapshot.skhdInstalled {
            notInstalled
        } else {
            installed
        }
    }

    // MARK: - skhd missing

    private var notInstalled: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                "skhd n'est pas installé : yabai n'a donc aucun raccourci clavier.",
                systemImage: "keyboard.badge.ellipsis"
            )
            .font(.system(size: 12))
            .foregroundStyle(.secondary)

            HStack {
                Button {
                    Task { await controller.installSkhd() }
                } label: {
                    Label("Installer skhd", systemImage: "arrow.down.circle")
                }
                .controlSize(.small)
                .disabled(controller.activity.isBusy)

                Text("yabai sans skhd, c'est un gestionnaire de fenêtres sans clavier.")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }

    // MARK: - skhd installed

    private var installed: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            if controller.isRawShortcutMode {
                rawEditor
            } else {
                structuredEditor
            }

            footer
        }
        .padding(.vertical, 2)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                StatusPill(state: controller.snapshot.skhdRunning ? .running : .stopped)

                Picker("", selection: $controller.shortcutModeFilter) {
                    Text("Tous les modes").tag("")
                    ForEach(controller.availableShortcutModes, id: \.self) { mode in
                        Text(mode).tag(mode)
                    }
                }
                .labelsHidden()
                .frame(width: 170)

                Spacer()

                Button {
                    Task { await controller.toggleSkhd() }
                } label: {
                    Label(
                        controller.snapshot.skhdRunning ? "Arrêter skhd" : "Démarrer skhd",
                        systemImage: controller.snapshot.skhdRunning ? "stop.fill" : "play.fill"
                    )
                }
                .controlSize(.small)
                .disabled(controller.activity.isBusy)
            }

            if controller.needsAccessibility {
                HStack(spacing: 8) {
                    Image(systemName: "lock.shield")
                        .foregroundStyle(.orange)
                    Text("skhd n'a pas pu démarrer : macOS lui refuse l'accès Accessibilité.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                    Button {
                        controller.openAccessibilitySettings()
                    } label: {
                        Text("Autoriser")
                            .font(.system(size: 11))
                    }
                    .controlSize(.small)
                }
                .padding(.vertical, 2)
            }
        }
    }

    private var structuredEditor: some View {
        VStack(spacing: 0) {
            if controller.visibleShortcuts.isEmpty {
                Text("Aucun raccourci dans ce mode.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 8)
            } else {
                ForEach(controller.visibleShortcuts) { binding in
                    ShortcutRow(binding: binding) { updated in
                        controller.updateShortcut(updated)
                    } onDelete: {
                        controller.removeShortcut(id: binding.id)
                    }
                    if binding.id != controller.visibleShortcuts.last?.id {
                        Divider()
                    }
                }
            }

            Divider()
            Button {
                controller.addShortcut()
            } label: {
                Label("Ajouter un raccourci", systemImage: "plus")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .padding(.top, 6)
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
    }

    private var rawEditor: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Édition brute de \(SkhdConfig.configFile())")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextEditor(text: $controller.rawShortcuts)
                .font(.system(size: 11, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(4)
                .frame(height: 210)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        }
    }

    private var footer: some View {
        HStack {
            Button {
                controller.isRawShortcutMode.toggle()
                if controller.isRawShortcutMode {
                    controller.rawShortcuts = SkhdConfig.serialize(controller.shortcutItems)
                }
            } label: {
                Label(
                    controller.isRawShortcutMode ? "Vue structurée" : "Mode texte",
                    systemImage: controller.isRawShortcutMode ? "list.bullet" : "text.alignleft"
                )
            }
            .controlSize(.small)

            Button {
                controller.loadShortcuts()
            } label: {
                Label("Recharger", systemImage: "arrow.counterclockwise")
            }
            .controlSize(.small)

            Spacer()

            Button {
                Task { await controller.saveShortcuts() }
            } label: {
                Label("Enregistrer et appliquer", systemImage: "checkmark.circle")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.small)
            .disabled(controller.activity.isBusy)
        }
    }
}

/// One row of the structured shortcut editor.
private struct ShortcutRow: View {
    let binding: SkhdBinding
    let onChange: (SkhdBinding) -> Void
    let onDelete: () -> Void

    @State private var modifiers: [SkhdModifier] = []
    @State private var key: String = ""

    /// The combination as it is shown in the cell.
    private var displayText: String {
        let symbols = SkhdModifier.order
            .filter { modifiers.contains($0) }
            .map(\.symbol)
            .joined()
        return symbols + key.uppercased()
    }

    var body: some View {
        HStack(spacing: 8) {
            ZStack {
                // The label is drawn by SwiftUI; the AppKit view sits on top
                // and only captures the keystroke.
                Text(displayText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.primary)

                KeyRecorder(modifiers: $modifiers, key: $key) { capturedModifiers, capturedKey in
                    modifiers = capturedModifiers
                    key = capturedKey
                    var updated = binding
                    updated.modifiers = capturedModifiers
                    updated.key = capturedKey
                    onChange(updated)
                }
                .frame(width: 84, height: 22)
            }
            .frame(width: 84, height: 22)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
            )
            .help("Cliquez puis appuyez sur la combinaison de touches voulue")

            // An empty title keeps SwiftUI from turning the field into a
            // labelled row, which would push the command to the far right.
            TextField("", text: Binding(
                get: { binding.action },
                set: { updated in
                    var copy = binding
                    copy.action = updated
                    onChange(copy)
                }
            ))
            .labelsHidden()
            .font(.system(size: 11, design: .monospaced))
            .textFieldStyle(.roundedBorder)
            .frame(maxWidth: .infinity)

            if let mode = binding.mode {
                Text(mode)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(Capsule().fill(Color.primary.opacity(0.08)))
            }

            Button(action: onDelete) {
                Image(systemName: "minus.circle")
                    .font(.system(size: 11))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
            .help("Supprimer ce raccourci")
        }
        .padding(.vertical, 3)
        .onAppear {
            modifiers = binding.modifiers
            key = binding.key
        }
    }
}
