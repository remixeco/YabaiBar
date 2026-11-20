import Foundation

/// Homebrew operations used by the update flow.
struct Homebrew {

    var isAvailable: Bool {
        FileManager.default.isExecutableFile(atPath: Shell.brewPath)
    }

    /// Returns true when Homebrew knows about a newer version of `formula`.
    ///
    /// `brew outdated` exits with 1 when it finds outdated formulae, so the exit
    /// code is not a reliable signal here — the output is.
    func isOutdated(_ formula: String) async -> Bool {
        guard isAvailable else { return false }
        let result = await Shell.run(Shell.brewPath, ["outdated", "--formula", formula])
        return !result.output.isEmpty
    }

    /// Refreshes Homebrew's package index.
    func update(onLine: @escaping @Sendable (String) -> Void) async -> CommandResult {
        await Shell.stream(Shell.brewPath, ["update"], onLine: onLine)
    }

    /// Upgrades a formula to its latest version.
    func upgrade(_ formula: String, onLine: @escaping @Sendable (String) -> Void) async -> CommandResult {
        await Shell.stream(Shell.brewPath, ["upgrade", formula], onLine: onLine)
    }

    /// Installs a formula.
    func install(_ formula: String, onLine: @escaping @Sendable (String) -> Void) async -> CommandResult {
        await Shell.stream(Shell.brewPath, ["install", formula], onLine: onLine)
    }
}
