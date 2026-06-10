import Foundation

struct RemoteProjectPickerFileSystem: ProjectPickerFileSystem {
    let destination: SSHDestination

    func directoryState(atPath path: String) -> ProjectPickerFileSystemDirectoryState {
        let quoted = RemoteCommandBuilder.quoteRemotePath(path)
        let command = "if [ -d \(quoted) ]; then echo dir; elif [ -e \(quoted) ]; then echo file; else echo missing; fi"
        guard let output = run(command)?.trimmingCharacters(in: .whitespacesAndNewlines) else {
            return .missing
        }
        switch output {
        case "dir": return .directory
        case "file": return .notDirectory
        default: return .missing
        }
    }

    func isReadableFile(atPath path: String) -> Bool {
        let quoted = RemoteCommandBuilder.quoteRemotePath(path)
        let output = run("if [ -r \(quoted) ]; then echo ok; fi")?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return output == "ok"
    }

    func contentsOfDirectory(atPath path: String) throws -> [ProjectPickerFileSystemDirectoryEntry] {
        let quoted = RemoteCommandBuilder.quoteRemotePath(path)
        let script = "cd \(quoted) && for e in * .*; do "
            + "case \"$e\" in '.'|'..'|'*'|'.*') continue ;; esac; "
            + "{ [ -e \"$e\" ] || [ -L \"$e\" ]; } || continue; "
            + "if [ -d \"$e\" ]; then printf 'd %s\\0' \"$e\"; "
            + "else printf 'f %s\\0' \"$e\"; fi; done"
        guard let output = run(script) else {
            throw RemoteProjectPickerError.listingFailed
        }
        return Self.parseEntries(output)
    }

    static func parseEntries(_ output: String) -> [ProjectPickerFileSystemDirectoryEntry] {
        output
            .split(separator: "\0", omittingEmptySubsequences: true)
            .compactMap { record -> ProjectPickerFileSystemDirectoryEntry? in
                guard record.count > 2 else { return nil }
                let type = record.first
                let name = String(record.dropFirst(2))
                guard !name.isEmpty else { return nil }
                return type == "d" ? .directory(name) : .file(name)
            }
    }

    private func run(_ remoteCommand: String) -> String? {
        let semaphore = DispatchSemaphore(value: 0)
        let box = ResultBox()
        Task {
            let result = try? await SSHCommandRunner.run(destination: destination, remoteCommand: remoteCommand)
            box.set(result)
            semaphore.signal()
        }
        semaphore.wait()
        guard let result = box.value, result.status == 0 else { return nil }
        return result.stdout
    }
}

enum RemoteProjectPickerError: LocalizedError {
    case listingFailed

    var errorDescription: String? {
        switch self {
        case .listingFailed: "Failed to list remote directory."
        }
    }
}

private final class ResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var stored: GitProcessResult?

    func set(_ result: GitProcessResult?) {
        lock.lock()
        defer { lock.unlock() }
        stored = result
    }

    var value: GitProcessResult? {
        lock.lock()
        defer { lock.unlock() }
        return stored
    }
}
