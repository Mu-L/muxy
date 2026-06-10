import Foundation

protocol RemoteFileOps: Sendable {
    func makeDirectory(at path: String) async throws
    func removeItem(at path: String) async throws
    func exists(at path: String) async -> Bool
}

struct LocalFileOps: RemoteFileOps {
    func makeDirectory(at path: String) async throws {
        try await GitProcessRunner.offMainThrowing {
            try FileManager.default.createDirectory(
                atPath: path,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    func removeItem(at path: String) async throws {
        try await GitProcessRunner.offMainThrowing {
            try FileManager.default.removeItem(atPath: path)
        }
    }

    func exists(at path: String) async -> Bool {
        await GitProcessRunner.offMain {
            FileManager.default.fileExists(atPath: path)
        }
    }
}

struct SSHFileOps: RemoteFileOps {
    let destination: SSHDestination

    func makeDirectory(at path: String) async throws {
        try await run("mkdir -p \(RemoteCommandBuilder.quoteRemotePath(path))")
    }

    func removeItem(at path: String) async throws {
        try await run("rm -rf \(RemoteCommandBuilder.quoteRemotePath(path))")
    }

    func exists(at path: String) async -> Bool {
        let quoted = RemoteCommandBuilder.quoteRemotePath(path)
        let result = try? await SSHCommandRunner.run(
            destination: destination,
            remoteCommand: "[ -e \(quoted) ] && echo yes || true"
        )
        return result?.stdout.trimmingCharacters(in: .whitespacesAndNewlines) == "yes"
    }

    private func run(_ remoteCommand: String) async throws {
        let result = try await SSHCommandRunner.run(destination: destination, remoteCommand: remoteCommand)
        guard result.status == 0 else {
            throw RemoteFileOpsError.commandFailed(result.stderr.isEmpty ? remoteCommand : result.stderr)
        }
    }
}

enum RemoteFileOpsError: LocalizedError {
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case let .commandFailed(message): message
        }
    }
}

extension WorkspaceContext {
    var fileOps: any RemoteFileOps {
        switch self {
        case .local: LocalFileOps()
        case let .ssh(destination): SSHFileOps(destination: destination)
        }
    }
}
