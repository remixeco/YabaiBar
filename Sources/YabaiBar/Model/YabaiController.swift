import Combine
import Foundation
import SwiftUI

/// One line in the activity log.
struct LogEntry: Identifiable, Equatable {
    enum Kind: Equatable {
        case info, success, warning, error, command
    }

    let id = UUID()
    let date: Date
    let kind: Kind
    let text: String

    init(kind: Kind, text: String, date: Date = Date()) {
        self.kind = kind
        self.text = text
        self.date = date
    }

    var time: String {
        Self.formatter.string(from: date)
    }

    private static let formatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}

/// Central coordinator: talks to yabai, Homebrew and launchd, and exposes the
/// result to the UI.
@MainActor
final class YabaiController: ObservableObject {

    /// A long running operation currently in progress.
    enum Activity: Equatable {
        case idle
        case working(String)

        var isBusy: Bool { self != .idle }
        var label: String {
            if case .working(let text) = self { return text }
            return ""
        }
    }

    @Published private(set) var snapshot = YabaiSnapshot()
    @Published var liveSettings = LiveSettings()
    @Published private(set) var activity: Activity = .idle
    @Published private(set) var log: [LogEntry] = []
    @Published private(set) var updateAvailable = false
    @Published var settings = AppSettings()

    // Shortcuts (skhd)
    @Published private(set) var shortcutItems: [SkhdItem] = []
    @Published var rawShortcuts: String = ""
    @Published var shortcutModeFilter: String = ""
    @Published var isRawShortcutMode = false

    /// Set when macOS refuses to start a daemon for lack of the Accessibility
    /// permission.
    @Published private(set) var needsAccessibility = false

    private let service = YabaiService()
    private let homebrew = Homebrew()
    private var polling: Task<Void, Never>?
    private var cancellables: Set<AnyCancellable> = []

    init(settings: AppSettings? = nil) {
        let settings = settings ?? AppSettings()
        self.settings = settings
        // Forward the settings' changes so that views observing the controller
        // (and the toggles bound to it) refresh with them.
        settings.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    // MARK: - Lifecycle

    private var didBootstrap = false

    func bootstrap() {
        guard !didBootstrap else { return }
        didBootstrap = true

        settings.syncLoginItem()

        Task {
            await refresh()
            await loadLiveSettings()
            loadShortcuts()
            if settings.startYabaiOnLaunch, !snapshot.isRunning, snapshot.isInstalled {
                await startYabai()
            }
            startPolling()
            if let last = settings.lastUpdateCheck,
               Date().timeIntervalSince(last) > 3600 {
                await checkForUpdates(silent: true)
            }
        }
    }

    private func startPolling() {
        polling?.cancel()
        polling = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                guard let self, !self.activity.isBusy else { continue }
                await self.refresh()
            }
        }
    }

    func shutdown() {
        polling?.cancel()
        polling = nil
    }

    // MARK: - State

    func refresh() async {
        let newSnapshot = await service.probe()
        let changed = newSnapshot != snapshot
        snapshot = newSnapshot
        if changed {
            record(.info, "État : \(newSnapshot.isRunning ? "en cours" : "arrêté"), version \(newSnapshot.version)")
        }
    }

    func loadLiveSettings() async {
        liveSettings = await service.readLiveSettings()
    }

    // MARK: - Service actions

    func startYabai() async {
        await perform("Démarrage de yabai") {
            let result = await self.service.start()
            if result.succeeded {
                self.record(.success, "yabai démarré.")
            } else {
                self.record(.error, "Échec du démarrage : \(result.combined)")
            }
            await self.refresh()
        }
    }

    func stopYabai() async {
        await perform("Arrêt de yabai") {
            let result = await self.service.stop()
            if result.succeeded {
                self.record(.success, "yabai arrêté.")
            } else {
                self.record(.error, "Échec de l'arrêt : \(result.combined)")
            }
            await self.refresh()
        }
    }

    func restartYabai() async {
        await perform("Redémarrage de yabai") {
            let result = await self.service.restart()
            if result.succeeded {
                self.record(.success, "yabai redémarré, configuration rechargée.")
            } else {
                self.record(.error, "Échec du redémarrage : \(result.combined)")
            }
            await self.refresh()
        }
    }

    /// yabai sources `yabairc` only at startup, so applying the configuration
    /// means restarting the service.
    func reloadConfiguration() async {
        await perform("Rechargement de la configuration") {
            let result = await self.service.restart()
            if result.succeeded {
                self.record(.success, "Configuration rechargée depuis \(Paths.yabaiConfigFile)")
            } else {
                self.record(.error, "Échec du rechargement : \(result.combined)")
            }
            await self.refresh()
        }
    }

    func installService() async {
        await perform("Installation du service") {
            let result = await self.service.installService()
            if result.succeeded {
                self.record(.success, "Service installé — yabai démarrera à l'ouverture de session.")
            } else {
                self.record(.error, "Installation impossible : \(result.combined)")
            }
            await self.refresh()
        }
    }

    func uninstallService() async {
        await perform("Désinstallation du service") {
            let result = await self.service.uninstallService()
            if result.succeeded {
                self.record(.success, "Service désinstallé.")
            } else {
                self.record(.error, "Désinstallation impossible : \(result.combined)")
            }
            await self.refresh()
        }
    }

    // MARK: - Configuration

    /// Applies the sliders to the running yabai instance, without a restart.
    func applyLiveSettings() async {
        await perform("Application des réglages") {
            for (key, value) in self.liveSettings.configPairs {
                let result = await self.service.setConfig(key: key, value: value)
                if result.succeeded {
                    self.record(.success, "\(key) = \(value)")
                } else {
                    self.record(.error, "\(key) : \(result.combined)")
                }
            }
        }
    }

    /// Writes the current sliders into `yabairc` so they survive a restart.
    func saveSettingsToConfigFile() async {
        await perform("Écriture de la configuration") {
            do {
                _ = try ConfigFile().apply(settings: self.liveSettings)
                self.record(.success, "Configuration écrite dans \(Paths.yabaiConfigFile)")
                self.record(.info, "Redémarre yabai pour prendre en compte les changements.")
            } catch {
                self.record(.error, "Écriture impossible : \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Updates

    func checkForUpdates(silent: Bool = false) async {
        await perform(silent ? "" : "Vérification des mises à jour") {
            self.updateAvailable = await self.homebrew.isOutdated("yabai")
            self.settings.lastUpdateCheck = Date()
            if self.updateAvailable {
                self.record(.warning, "Une mise à jour de yabai est disponible.")
            } else if !silent {
                self.record(.success, "yabai \(self.snapshot.version) est à jour.")
            }
        }
    }

    /// Runs `brew update` then `brew upgrade yabai`, and restarts the service so
    /// the new binary is the one running.
    func performUpdate() async {
        await perform("Mise à jour de yabai") {
            self.record(.command, "brew update")
            let update = await self.homebrew.update { line in
                Task { @MainActor in self.recordStream(line) }
            }
            if !update.succeeded {
                self.record(.error, "Échec de « brew update » : \(update.combined)")
                return
            }

            self.record(.command, "brew upgrade yabai")
            let upgrade = await self.homebrew.upgrade("yabai") { line in
                Task { @MainActor in self.recordStream(line) }
            }
            if !upgrade.succeeded {
                self.record(.error, "Échec de « brew upgrade yabai » : \(upgrade.combined)")
                return
            }

            if upgrade.output.contains("already up-to-date")
                || upgrade.output.contains("already installed")
                || upgrade.output.contains("Nothing to upgrade") {
                self.record(.success, "yabai était déjà à jour.")
            } else {
                self.record(.success, "yabai mis à jour.")
            }

            // The running daemon still holds the old binary: restart it.
            self.record(.info, "Redémarrage du service avec le nouveau binaire…")
            let restart = await self.service.restart()
            if !restart.succeeded {
                self.record(.warning, "Le service n'a pas redémarré : \(restart.combined)")
            }

            self.updateAvailable = false
            self.settings.lastUpdateCheck = Date()
            await self.refresh()
        }
    }

    /// Installs skhd, the hotkey daemon that pairs with yabai.
    func installSkhd() async {
        await perform("Installation de skhd") {
            let result = await self.homebrew.install("skhd") { line in
                Task { @MainActor in self.recordStream(line) }
            }
            if result.succeeded {
                self.record(.success, "skhd installé. Redémarre skhd pour activer les raccourcis.")
            } else {
                self.record(.error, "Installation impossible : \(result.combined)")
            }
            await self.refresh()
        }
    }

    // MARK: - Shortcuts

    /// Reloads `skhdrc` from disk.
    func loadShortcuts() {
        rawShortcuts = SkhdConfig.contents()
        shortcutItems = SkhdConfig.parse(rawShortcuts)
        if !shortcutModeFilter.isEmpty,
           !SkhdConfig.modes(in: shortcutItems).contains(shortcutModeFilter) {
            shortcutModeFilter = ""
        }
    }

    /// The bindings currently listed, honouring the mode filter.
    var visibleShortcuts: [SkhdBinding] {
        shortcutItems.compactMap { item in
            guard case .binding(let binding) = item else { return nil }
            if !shortcutModeFilter.isEmpty, binding.mode != shortcutModeFilter { return nil }
            return binding
        }
    }

    /// Every mode declared in the file, plus the modes used by bindings.
    var availableShortcutModes: [String] {
        var modes = SkhdConfig.modes(in: shortcutItems)
        for binding in visibleShortcuts {
            if let mode = binding.mode, !modes.contains(mode) {
                modes.append(mode)
            }
        }
        return modes
    }

    /// Replaces one binding.
    func updateShortcut(_ binding: SkhdBinding) {
        for index in shortcutItems.indices {
            if case .binding(let existing) = shortcutItems[index], existing.id == binding.id {
                shortcutItems[index] = .binding(binding)
                return
            }
        }
    }

    /// Removes one binding.
    func removeShortcut(id: SkhdBinding.ID) {
        shortcutItems.removeAll { item in
            if case .binding(let binding) = item { return binding.id == id }
            return false
        }
    }

    /// Appends an empty binding at the end of the file.
    func addShortcut() {
        var binding = SkhdBinding()
        binding.modifiers = [.alt]
        binding.key = "h"
        binding.action = "yabai -m window --focus west"
        if !shortcutModeFilter.isEmpty { binding.mode = shortcutModeFilter }
        shortcutItems.append(.binding(binding))
    }

    /// Writes the shortcuts to disk and applies them by restarting skhd.
    func saveShortcuts() async {
        await perform("Enregistrement des raccourcis") {
            do {
                if self.isRawShortcutMode {
                    try SkhdConfig.write(self.rawShortcuts)
                    self.shortcutItems = SkhdConfig.parse(self.rawShortcuts)
                } else {
                    try SkhdConfig.write(SkhdConfig.serialize(self.shortcutItems))
                    self.rawShortcuts = SkhdConfig.contents()
                }
                self.record(.success, "Raccourcis écrits dans \(SkhdConfig.configFile())")

                if self.snapshot.skhdInstalled {
                    let restart = await self.service.restartSkhd()
                    if restart.succeeded {
                        self.record(.success, "skhd redémarré, les raccourcis sont actifs.")
                    } else {
                        self.record(.warning, "skhd n'a pas redémarré : \(restart.combined)")
                    }
                } else {
                    self.record(.info, "Installe skhd pour activer ces raccourcis.")
                }
                await self.refresh()
            } catch {
                self.record(.error, "Écriture impossible : \(error.localizedDescription)")
            }
        }
    }

    /// Starts or stops the skhd service.
    func toggleSkhd() async {
        await perform(snapshot.skhdRunning ? "Arrêt de skhd" : "Démarrage de skhd") {
            let result = self.snapshot.skhdRunning
                ? await self.service.stopSkhd()
                : await self.service.startSkhd()
            if result.succeeded {
                self.needsAccessibility = false
                self.record(.success, self.snapshot.skhdRunning ? "skhd arrêté." : "skhd démarré.")
            } else {
                self.record(.error, "Échec de l'opération : \(result.combined)")
                if result.combined.lowercased().contains("accessibility") {
                    self.needsAccessibility = true
                    self.record(.warning, "skhd a besoin de l'accès Accessibilité. Utilise le bouton dédié pour l'autoriser.")
                }
            }
            await self.refresh()
        }
    }

    /// Opens the macOS pane where the Accessibility permission is granted.
    func openAccessibilitySettings() {
        let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )
        if let url {
            NSWorkspace.shared.open(url)
        }
    }

    /// Installs yabai itself through Homebrew.
    func installYabai() async {
        await perform("Installation de yabai") {
            let result = await self.homebrew.install("yabai") { line in
                Task { @MainActor in self.recordStream(line) }
            }
            if result.succeeded {
                self.record(.success, "yabai installé.")
                self.record(.info, "Installation du service de démarrage…")
                let service = await self.service.installService()
                if service.succeeded {
                    self.record(.success, "Service installé.")
                }
                _ = await self.service.start()
            } else {
                self.record(.error, "Installation impossible : \(result.combined)")
            }
            await self.refresh()
        }
    }

    // MARK: - App actions

    func relaunchApp() {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(
            at: Bundle.main.bundleURL,
            configuration: configuration
        ) { _, error in
            if let error {
                Task { @MainActor in
                    self.record(.error, "Impossible de relancer l'app : \(error.localizedDescription)")
                }
                return
            }
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }

    func openConfigFile() {
        let path = Paths.yabaiConfigFile
        guard FileManager.default.fileExists(atPath: path) else {
            record(.warning, "Aucune configuration à \(path)")
            return
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    func revealConfigFile() {
        NSWorkspace.shared.selectFile(
            nil,
            inFileViewerRootedAtPath: (Paths.yabaiConfigFile as NSString).deletingLastPathComponent
        )
    }

    func openLog(_ path: String) {
        guard FileManager.default.fileExists(atPath: path) else {
            record(.warning, "Journal introuvable : \(path)")
            return
        }
        NSWorkspace.shared.open(URL(fileURLWithPath: path))
    }

    // MARK: - Internals

    private func perform(_ label: String, _ work: @escaping @MainActor () async -> Void) async {
        guard !activity.isBusy else { return }
        if !label.isEmpty {
            activity = .working(label)
            record(.command, label)
        }
        await work()
        activity = .idle
    }

    /// Empties the activity log.
    func clearLog() {
        log.removeAll()
    }

    /// Records a line streamed by Homebrew, colouring warnings and errors.
    private func recordStream(_ line: String) {
        let lowered = line.lowercased()
        let kind: LogEntry.Kind
        if lowered.hasPrefix("error") {
            kind = .error
        } else if lowered.hasPrefix("warning") {
            kind = .warning
        } else {
            kind = .info
        }
        record(kind, line)
    }

    private func record(_ kind: LogEntry.Kind, _ text: String) {
        log.append(LogEntry(kind: kind, text: text))
        if log.count > 400 {
            log.removeFirst(log.count - 400)
        }
    }
}
