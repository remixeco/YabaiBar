import SwiftUI

/// The main window: state, live settings, updates and diagnostics.
struct DashboardView: View {
    @EnvironmentObject private var controller: YabaiController

    private var status: StatusPill.State {
        if controller.activity.isBusy { return .busy }
        if controller.snapshot.isRunning { return .running }
        if controller.snapshot.isInstalled { return .stopped }
        return .unknown
    }

    var body: some View {
        VStack(spacing: 0) {
            Form {
                stateSection
                shortcutsSection
                settingsSection
                updateSection
                diagnosticsSection
            }
            .formStyle(.grouped)

            Divider()
            LogConsole()
                .frame(height: 170)
        }
        .frame(minWidth: 640, minHeight: 660)
        .task { controller.bootstrap() }
    }

    // MARK: - State

    private var stateSection: some View {
        Section {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text("Yabai")
                            .font(.system(size: 15, weight: .semibold))
                        StatusPill(state: status)
                    }
                    Text(stateDescription)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }

                Spacer()

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
                        controller.snapshot.isRunning ? "Arrêter" : "Démarrer",
                        systemImage: controller.snapshot.isRunning ? "stop.fill" : "play.fill"
                    )
                    .frame(width: 110)
                }
                .buttonStyle(ProminentButtonStyle(tint: controller.snapshot.isRunning ? .red : .green))
                .disabled(controller.activity.isBusy)
            }
            .padding(.vertical, 4)

            HStack(spacing: 10) {
                Button {
                    Task { await controller.restartYabai() }
                } label: {
                    Label("Redémarrer", systemImage: "arrow.clockwise")
                }
                Button {
                    Task { await controller.reloadConfiguration() }
                } label: {
                    Label("Recharger la configuration", systemImage: "arrow.triangle.2.circlepath")
                }
                Button {
                    controller.openConfigFile()
                } label: {
                    Label("Ouvrir yabairc", systemImage: "doc.text")
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(controller.activity.isBusy)
        } header: {
            Text("État")
        }
    }

    private var stateDescription: String {
        guard controller.snapshot.isInstalled else {
            return "Yabai n'est pas installé. Utilisez le bouton ci-dessous pour l'installer."
        }
        if let activity = controller.activity.label.isEmpty ? nil : controller.activity.label {
            return activity + "…"
        }
        if controller.snapshot.isRunning {
            return "Version \(controller.snapshot.version) · \(controller.snapshot.spaceCount) espaces · \(controller.snapshot.windowCount) fenêtres"
        }
        return "Version \(controller.snapshot.version) · le service est arrêté"
    }

    // MARK: - Shortcuts

    private var shortcutsSection: some View {
        Section {
            ShortcutsView()
        } header: {
            Text("Raccourcis clavier")
        } footer: {
            Text("Ces raccourcis sont ceux de skhd, le daemon qui pilote yabai au clavier. Le fichier édité est \(SkhdConfig.configFile()).")
        }
    }

    // MARK: - Settings

    private var settingsSection: some View {
        Section {
            Picker("Disposition", selection: $controller.liveSettings.layout) {
                ForEach(LiveSettings.Layout.allCases) { layout in
                    Text(layout.label).tag(layout)
                }
            }
            .pickerStyle(.segmented)

            Picker("Placement", selection: $controller.liveSettings.windowPlacement) {
                ForEach(LiveSettings.Placement.allCases) { placement in
                    Text(placement.label).tag(placement)
                }
            }
            .pickerStyle(.segmented)

            stepper("Écart entre les fenêtres", value: $controller.liveSettings.windowGap, range: 0...60)

            HStack(spacing: 16) {
                stepper("Gauche", value: $controller.liveSettings.leftPadding, range: 0...120)
                stepper("Droite", value: $controller.liveSettings.rightPadding, range: 0...120)
            }
            HStack(spacing: 16) {
                stepper("Haut", value: $controller.liveSettings.topPadding, range: 0...120)
                stepper("Bas", value: $controller.liveSettings.bottomPadding, range: 0...120)
            }

            HStack {
                Button {
                    Task { await controller.applyLiveSettings() }
                } label: {
                    Label("Appliquer maintenant", systemImage: "bolt.fill")
                }
                .disabled(controller.activity.isBusy)

                Button {
                    Task { await controller.saveSettingsToConfigFile() }
                } label: {
                    Label("Enregistrer dans yabairc", systemImage: "square.and.arrow.down")
                }
                .disabled(controller.activity.isBusy)

                Spacer()

                Button {
                    Task { await controller.loadLiveSettings() }
                } label: {
                    Label("Relire", systemImage: "arrow.counterclockwise")
                }
                .buttonStyle(.borderless)
                .disabled(controller.activity.isBusy)
            }
            .controlSize(.small)
        } header: {
            Text("Réglages")
        } footer: {
            Text("« Appliquer » modifie la fenêtre en cours sans redémarrer. « Enregistrer » écrit dans \(Paths.yabaiConfigFile), la configuration relue par yabai au démarrage.")
        }
    }

    private func stepper(_ title: String, value: Binding<Int>, range: ClosedRange<Int>) -> some View {
        Stepper(value: value, in: range) {
            HStack {
                Text(title)
                Spacer()
                Text("\(value.wrappedValue) px")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Updates

    private var updateSection: some View {
        Section {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Version installée : \(controller.snapshot.version)")
                        .font(.system(size: 12))
                    if let check = controller.settings.lastUpdateCheck {
                        Text("Dernière vérification : \(check.formatted(date: .abbreviated, time: .shortened))")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    if controller.updateAvailable {
                        Text("Une mise à jour est disponible.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.orange)
                    }
                }

                Spacer()

                Button {
                    Task { await controller.checkForUpdates() }
                } label: {
                    Label("Vérifier", systemImage: "magnifyingglass")
                }
                .disabled(controller.activity.isBusy)

                Button {
                    Task { await controller.performUpdate() }
                } label: {
                    Label("Mettre à jour", systemImage: "arrow.down.circle")
                }
                .disabled(controller.activity.isBusy)
            }
            .controlSize(.small)
        } header: {
            Text("Mises à jour")
        } footer: {
            Text("La mise à jour lance « brew update » puis « brew upgrade yabai », et redémarre le service pour charger le nouveau binaire.")
        }
    }

    // MARK: - Diagnostics

    private var diagnosticsSection: some View {
        Section {
            DetailRow(title: "Binaire", value: Paths.yabaiBinary ?? "non installé", monospaced: true)
            DetailRow(title: "Configuration", value: Paths.yabaiConfigFile, monospaced: true)
            DetailRow(title: "Service launchd", value: Paths.yabaiLaunchAgent, monospaced: true)
            DetailRow(
                title: "Service",
                value: controller.snapshot.serviceLoaded ? "chargé" : (controller.snapshot.serviceInstalled ? "installé, non chargé" : "non installé")
            )

            Toggle("Démarrer yabai à l'ouverture de l'app", isOn: $controller.settings.startYabaiOnLaunch)
            Toggle("Lancer l'app à l'ouverture de session", isOn: $controller.settings.launchAtLogin)
                .onChange(of: controller.settings.launchAtLogin) { _, _ in
                    controller.settings.syncLoginItem()
                }

            HStack {
                Button {
                    if controller.snapshot.serviceInstalled {
                        Task { await controller.uninstallService() }
                    } else {
                        Task { await controller.installService() }
                    }
                } label: {
                    Label(
                        controller.snapshot.serviceInstalled ? "Désinstaller le service" : "Installer le service",
                        systemImage: "gearshape.2"
                    )
                }
                .disabled(controller.activity.isBusy)

                Button {
                    controller.openLog(Paths.yabaiStdoutLog)
                } label: {
                    Label("Journal", systemImage: "doc.plaintext")
                }
            }
            .controlSize(.small)
        } header: {
            Text("Diagnostic")
        }
    }
}
