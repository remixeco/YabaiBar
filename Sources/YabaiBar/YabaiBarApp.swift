import SwiftUI

@main
struct YabaiBarApp: App {
    @StateObject private var environment = AppEnvironment()

    init() {
        // `YabaiBar --screenshots <dir>` renders the UI to PNG files and exits.
        if let directory = ScreenshotGenerator.outputDirectory() {
            Task { @MainActor in
                await ScreenshotGenerator.run(into: directory)
                exit(EXIT_SUCCESS)
            }
        }
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarPanel()
                .environmentObject(environment)
                .environmentObject(environment.controller)
        } label: {
            Image(nsImage: MenubarIcon.image(for: iconState))
                .renderingMode(.original)
        }
        .menuBarExtraStyle(.window)
        .commands {
            CommandGroup(replacing: .appInfo) {
                Button("À propos de YabaiBar") {
                    environment.showAbout()
                }
            }

            CommandGroup(replacing: .appTermination) {
                Button("Quitter YabaiBar") {
                    NSApp.terminate(nil)
                }
                .keyboardShortcut("q")
            }

            CommandGroup(after: .appInfo) {
                Button("Tableau de bord") {
                    environment.showDashboard()
                }
                .keyboardShortcut("d", modifiers: [.command])

                Button("Relancer l'app") {
                    environment.controller.relaunchApp()
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }

            CommandMenu("Yabai") {
                Button(environment.controller.snapshot.isRunning ? "Arrêter" : "Démarrer") {
                    Task {
                        if environment.controller.snapshot.isRunning {
                            await environment.controller.stopYabai()
                        } else {
                            await environment.controller.startYabai()
                        }
                    }
                }
                .disabled(environment.controller.activity.isBusy)

                Button("Redémarrer") {
                    Task { await environment.controller.restartYabai() }
                }
                .disabled(environment.controller.activity.isBusy)

                Button("Recharger la configuration") {
                    Task { await environment.controller.reloadConfiguration() }
                }
                .disabled(environment.controller.activity.isBusy)

                Divider()

                Button("Mettre à jour yabai") {
                    Task { await environment.controller.performUpdate() }
                }
                .disabled(environment.controller.activity.isBusy)
            }
        }
    }

    private var iconState: MenubarIcon.State {
        if environment.controller.activity.isBusy { return .busy }
        return environment.controller.snapshot.isRunning ? .running : .stopped
    }
}
