import Foundation

/// Outcome of a shell command.
struct CommandResult: Sendable {
    var status: Int32 = -1
    var stdout: String = ""
    var stderr: String = ""

    var succeeded: Bool { status == 0 }
    var output: String { stdout.trimmingCharacters(in: .whitespacesAndNewlines) }
    var errors: String { stderr.trimmingCharacters(in: .whitespacesAndNewlines) }

    /// stdout and stderr joined, for display purposes.
    var combined: String {
        var parts: [String] = []
        if !output.isEmpty { parts.append(output) }
        if !errors.isEmpty { parts.append(errors) }
        return parts.joined(separator: "\n")
    }
}

/// Thin wrapper around `Process` used to talk to `yabai`, `brew` and `launchctl`.
///
/// Every command inherits a Homebrew-aware environment, because a macOS app
/// launched from Finder has a minimal `PATH` that does not include
/// `/opt/homebrew/bin`.
enum Shell {

    /// Homebrew prefix, detected from the environment then from well-known locations.
    static let homebrewPrefix: String = {
        if let prefix = ProcessInfo.processInfo.environment["HOMEBREW_PREFIX"], !prefix.isEmpty {
            return prefix
        }
        for candidate in ["/opt/homebrew", "/usr/local", "/home/linuxbrew/.linuxbrew"] {
            if FileManager.default.isExecutableFile(atPath: candidate + "/bin/brew") {
                return candidate
            }
        }
        return "/opt/homebrew"
    }()

    static var brewPath: String { homebrewPrefix + "/bin/brew" }

    /// Locates an executable on the PATH, with Homebrew's `bin` prepended.
    static func which(_ tool: String) -> String? {
        var candidates = [homebrewPrefix + "/bin/" + tool, "/usr/bin/" + tool, "/bin/" + tool]
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            candidates += path.split(separator: ":").map { $0 + "/" + tool }
        }
        for candidate in candidates where FileManager.default.isExecutableFile(atPath: candidate) {
            return candidate
        }
        return nil
    }

    /// Environment handed to every child process.
    static func environment(extra: [String: String] = [:]) -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        var path = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        if !path.contains(homebrewPrefix + "/bin") {
            path = homebrewPrefix + "/bin:" + path
        }
        environment["PATH"] = path
        environment["HOMEBREW_PREFIX"] = homebrewPrefix
        environment["HOMEBREW_CELLAR"] = homebrewPrefix + "/Cellar"
        environment["HOMEBREW_REPOSITORY"] = homebrewPrefix + "/Homebrew"
        // Homebrew would otherwise auto-update before every command, doubling the
        // duration of the update flow.
        environment["HOMEBREW_NO_AUTO_UPDATE"] = "1"
        environment["HOMEBREW_NO_ANALYTICS"] = "1"
        environment["HOMEBREW_NO_ENV_HINTS"] = "1"
        environment["NO_COLOR"] = "1"
        environment["NONINTERACTIVE"] = "1"
        for (key, value) in extra { environment[key] = value }
        return environment
    }

    /// Runs a command and waits for it to finish, collecting stdout and stderr.
    static func run(_ path: String, _ arguments: [String]) async -> CommandResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = arguments
                process.environment = environment()

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe
                process.standardInput = FileHandle.nullDevice

                do {
                    try process.run()
                } catch {
                    continuation.resume(returning: CommandResult(
                        status: -1,
                        stdout: "",
                        stderr: "Impossible de lancer \(path): \(error.localizedDescription)"
                    ))
                    return
                }

                var outData = Data()
                var errData = Data()
                let group = DispatchGroup()
                group.enter()
                group.enter()
                DispatchQueue.global(qos: .utility).async {
                    outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    group.leave()
                }
                DispatchQueue.global(qos: .utility).async {
                    errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    group.leave()
                }

                process.waitUntilExit()
                group.wait()

                continuation.resume(returning: CommandResult(
                    status: process.terminationStatus,
                    stdout: String(decoding: outData, as: UTF8.self),
                    stderr: String(decoding: errData, as: UTF8.self)
                ))
            }
        }
    }

    /// Runs a command synchronously and discards its output.
    ///
    /// Used for the short `launchctl` calls that have to happen inside a
    /// synchronous code path.
    @discardableResult
    static func runSync(_ path: String, _ arguments: [String]) -> CommandResult {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.environment = environment()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()
            return CommandResult(status: process.terminationStatus)
        } catch {
            return CommandResult(status: -1, stdout: "", stderr: error.localizedDescription)
        }
    }

    /// Runs a command, forwarding each output line to `onLine` as it arrives.
    /// Used for long operations such as `brew update`, where progress matters.
    static func stream(
        _ path: String,
        _ arguments: [String],
        onLine: @escaping @Sendable (String) -> Void
    ) async -> CommandResult {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: path)
                process.arguments = arguments
                process.environment = environment()

                let outPipe = Pipe()
                let errPipe = Pipe()
                process.standardOutput = outPipe
                process.standardError = errPipe
                process.standardInput = FileHandle.nullDevice

                let collector = LineCollector(onLine: onLine)
                outPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if data.isEmpty {
                        handle.readabilityHandler = nil
                        collector.flush()
                        return
                    }
                    collector.consume(String(decoding: data, as: UTF8.self))
                }
                errPipe.fileHandleForReading.readabilityHandler = { handle in
                    let data = handle.availableData
                    if data.isEmpty {
                        handle.readabilityHandler = nil
                        collector.flush()
                        return
                    }
                    collector.consume(String(decoding: data, as: UTF8.self))
                }

                do {
                    try process.run()
                } catch {
                    outPipe.fileHandleForReading.readabilityHandler = nil
                    errPipe.fileHandleForReading.readabilityHandler = nil
                    continuation.resume(returning: CommandResult(
                        status: -1,
                        stdout: "",
                        stderr: "Impossible de lancer \(path): \(error.localizedDescription)"
                    ))
                    return
                }

                process.waitUntilExit()
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil
                collector.flush()

                continuation.resume(returning: CommandResult(
                    status: process.terminationStatus,
                    stdout: collector.standardOutput,
                    stderr: collector.standardError
                ))
            }
        }
    }
}

/// Splits a character stream into lines and forwards them, thread-safely.
private final class LineCollector: @unchecked Sendable {
    private let lock = NSLock()
    private let onLine: @Sendable (String) -> Void
    private var stdoutBuffer = ""
    private var stderrBuffer = ""
    private var pending = ""

    init(onLine: @escaping @Sendable (String) -> Void) {
        self.onLine = onLine
    }

    func consume(_ chunk: String) {
        lock.lock()
        stdoutBuffer += chunk
        pending += chunk
        let lines = pending.components(separatedBy: "\n")
        pending = lines.last ?? ""
        lock.unlock()

        for line in lines.dropLast() where !line.isEmpty {
            onLine(line)
        }
    }

    var standardOutput: String {
        lock.lock()
        defer { lock.unlock() }
        return stdoutBuffer
    }

    var standardError: String {
        lock.lock()
        defer { lock.unlock() }
        return stderrBuffer
    }

    func flush() {
        lock.lock()
        let remainder = pending
        pending = ""
        lock.unlock()
        if !remainder.isEmpty { onLine(remainder) }
    }
}
