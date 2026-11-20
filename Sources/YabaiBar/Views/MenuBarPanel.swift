import SwiftUI

/// The menu bar panel: everything needed to drive yabai without a terminal.
struct MenuBarPanel: View {
    @EnvironmentObject private var environment: AppEnvironment
    @EnvironmentObject private var controller: YabaiController

    private var status: StatusPill.State {
        if controller.activity.isBusy { return .busy }
        if controller.snapshot.isRunning { return .running }
        if controller.snapshot.isInstalled { return .stopped }
        return .unknown
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().padding(.vertical, 8)

            if !controller.snapshot.isInstalled {
                notInstalled
            } else {
                controls
            }

            Divider().padding(.vertical, 8)

            secondaryActions
            Divider().padding(.vertical, 8)
            footer
        }
        .padding(12)
        .frame(width: 300)
        .task { controller.bootstrap() }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Yabai")
                    .font(.system(size: 14, weight: .semibold))
                Spacer()
                StatusPill(state: status)
            }

            Text(subtitle)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var subtitle: String {
        guard controller.snapshot.isInstalled else {
            return "Non installé"
        }
        var parts = ["v\(controller.snapshot.version)"]
        if controller.snapshot.isRunning {
            parts.append("\(controller.snapshot.spaceCount) espace\(controller.snapshot.spaceCount > 1 ? "s" : "")")
            parts.append("\(controller.snapshot.windowCount) fenêtre\(controller.snapshot.windowCount > 1 ? "s" : "")")
        } else {
            parts.append("arrêté")
        }
        return parts.joined(separator: " · ")
    }

    private var notInstalled: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Yabai n'est pas installé sur ce Mac.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Button {
                Task { await controller.installYabai() }
            } label: {
                Label("Installer via Homebrew", systemImage: "arrow.down.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(ProminentButtonStyle())
            .disabled(controller.activity.isBusy)
        }
    }

    private var controls: some View {
        VStack(spacing: 6) {
            Button {
                Task {
                    if controller.snapshot.isRunning {
                        await controller.stopYabai()
                    } else {
                        await controller.startYabai()
                    }
                }
            } label: {
                Label(
                    controller.snapshot.isRunning ? "Arrêter yabai" : "Démarrer yabai",
                    systemImage: controller.snapshot.isRunning ? "stop.fill" : "play.fill"
                )
            }
            .buttonStyle(ProminentButtonStyle(tint: controller.snapshot.isRunning ? .red : .green))
            .disabled(controller.activity.isBusy)

            HStack(spacing: 6) {
                Button {
                    Task { await controller.restartYabai() }
                } label: {
                    Label("Redémarrer", systemImage: "arrow.clockwise")
                }
                .buttonStyle(QuietButtonStyle())

                Button {
                    Task { await controller.reloadConfiguration() }
                } label: {
                    Label("Recharger config", systemImage: "arrow.triangle.2.circlepath")
                }
                .buttonStyle(QuietButtonStyle())
            }
            .disabled(controller.activity.isBusy)
        }
    }

    private var secondaryActions: some View {
        VStack(alignment: .leading, spacing: 1) {
            PanelButton(title: "Tableau de bord", systemImage: "square.grid.2x2") {
                environment.showDashboard()
            }
            PanelButton(title: "Ouvrir la configuration", systemImage: "doc.text") {
                controller.openConfigFile()
            }
            PanelButton(title: "Répertoire de configuration", systemImage: "folder") {
                controller.revealConfigFile()
            }
            PanelButton(title: "Journal de yabai", systemImage: "doc.plaintext") {
                controller.openLog(Paths.yabaiStdoutLog)
            }
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 1) {
            if controller.updateAvailable {
                PanelButton(title: "Mettre à jour yabai", systemImage: "arrow.down.circle.fill", tint: .orange) {
                    Task { await controller.performUpdate() }
                }
            } else {
                PanelButton(title: "Vérifier les mises à jour", systemImage: "arrow.clockwise.circle") {
                    Task { await controller.checkForUpdates() }
                }
            }

            Divider().padding(.vertical, 4)

            PanelButton(title: "Relancer l'app", systemImage: "arrow.clockwise") {
                controller.relaunchApp()
            }
            PanelButton(title: "Quitter", systemImage: "power") {
                NSApp.terminate(nil)
            }
        }
    }
}

/// A full width menu row inside the menu bar panel.
private struct PanelButton: View {
    let title: String
    let systemImage: String
    var tint: Color = .primary
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 12))
                    .frame(width: 16)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.system(size: 12))
                    .foregroundStyle(tint)
                Spacer(minLength: 0)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 2)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
