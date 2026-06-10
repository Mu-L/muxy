import Foundation

enum SSHCommandRunner {
    static func run(
        destination: SSHDestination,
        remoteCommand: String,
        batch: Bool = true,
        lineLimit: Int? = nil
    ) async throws -> GitProcessResult {
        let options = batch ? SSHDestination.batchOptions : SSHDestination.connectOptions
        let arguments = destination.connectionArguments + options + ["-T", destination.target, "--", remoteCommand]
        let resolved = ResolvedLaunch(
            executable: "/usr/bin/ssh",
            arguments: arguments,
            workingDirectory: nil
        )
        return try await GitProcessRunner.runResolved(resolved, lineLimit: lineLimit)
    }
}
