import Foundation
import Testing

@testable import Muxy

@Suite("SSHDestination connection arguments")
struct SSHDestinationTests {
    @Test("bare host defers everything to ssh config")
    func bareHost() {
        let destination = SSHDestination(host: "prod")
        #expect(destination.target == "prod")
        #expect(destination.connectionArguments.isEmpty)
    }

    @Test("user is folded into the target")
    func userTarget() {
        let destination = SSHDestination(host: "1.2.3.4", user: "deploy")
        #expect(destination.target == "deploy@1.2.3.4")
    }

    @Test("port and identity file become ssh options")
    func portAndIdentity() {
        let destination = SSHDestination(host: "prod", port: 2222, identityFile: "~/.ssh/id_ed25519")
        #expect(destination.connectionArguments == ["-p", "2222", "-i", "~/.ssh/id_ed25519", "-o", "IdentitiesOnly=yes"])
    }

    @Test("empty advanced fields are dropped")
    func emptyFieldsDropped() {
        let destination = SSHDestination(host: "prod", user: "", identityFile: "")
        #expect(destination.user == nil)
        #expect(destination.identityFile == nil)
        #expect(destination.connectionArguments.isEmpty)
    }

    @Test("ssh workspace data round-trips advanced fields")
    func dataRoundTrip() throws {
        let data = SSHWorkspaceData(host: "prod", remoteRoot: "~/code", port: 2200, user: "ci", identityFile: "~/k")
        let decoded = try JSONDecoder().decode(SSHWorkspaceData.self, from: JSONEncoder().encode(data))
        #expect(decoded == data)
        #expect(decoded.destination.target == "ci@prod")
        #expect(decoded.destination.connectionArguments.contains("2200"))
    }
}

@Suite("CommandTransform routing")
struct CommandTransformTests {
    private let destination = SSHDestination(host: "prod", remoteRoot: "~/code")

    @Test("local context is identity")
    func localIsIdentity() {
        let resolved = CommandTransform.resolve(
            executable: "/usr/bin/env",
            arguments: ["git", "status"],
            workingDirectory: "/Users/me/proj",
            in: .local
        )
        #expect(resolved.executable == "/usr/bin/env")
        #expect(resolved.arguments == ["git", "status"])
        #expect(resolved.workingDirectory == "/Users/me/proj")
    }

    @Test("ssh context wraps git as a non-tty remote command")
    func sshWrapsGit() {
        let resolved = CommandTransform.resolve(
            executable: "/usr/bin/env",
            arguments: ["git", "-C", "~/code/api", "status"],
            workingDirectory: nil,
            in: .ssh(destination)
        )
        #expect(resolved.executable == "/usr/bin/ssh")
        #expect(resolved.workingDirectory == nil)
        #expect(resolved.arguments.contains("-T"))
        #expect(resolved.arguments.contains("prod"))
        #expect(resolved.arguments.last == "/usr/bin/env git -C ~/code/api status")
    }

    @Test("ssh folds working directory into the remote command")
    func sshFoldsWorkingDirectory() {
        let resolved = CommandTransform.resolve(
            executable: "npm",
            arguments: ["run", "build"],
            workingDirectory: "~/code/api",
            in: .ssh(destination)
        )
        #expect(resolved.arguments.last == "cd ~/code/api && npm run build")
    }

    @Test("ssh exports environment before the command")
    func sshExportsEnvironment() {
        let resolved = CommandTransform.resolve(
            executable: "make",
            arguments: [],
            workingDirectory: "~/code/api",
            environment: ["CI": "1", "TOKEN": "a b"],
            in: .ssh(destination)
        )
        #expect(resolved.arguments.last == "export CI=1; export TOKEN='a b'; cd ~/code/api && make")
    }

    @Test("shell strings are wrapped, not re-escaped")
    func sshShellOpaque() {
        let resolved = CommandTransform.resolveShell(
            shellCommand: "echo $HOME && ls -la",
            workingDirectory: "~/code/api",
            in: .ssh(destination)
        )
        #expect(resolved.arguments.last == "cd ~/code/api && ( echo $HOME && ls -la )")
    }

    @Test("local shell uses /bin/sh -c")
    func localShell() {
        let resolved = CommandTransform.resolveShell(
            shellCommand: "echo hi",
            workingDirectory: "/tmp",
            in: .local
        )
        #expect(resolved.executable == "/bin/sh")
        #expect(resolved.arguments == ["-c", "echo hi"])
        #expect(resolved.workingDirectory == "/tmp")
    }
}

@Suite("RemoteCommandBuilder quoting")
struct RemoteCommandBuilderTests {
    @Test("leading tilde is preserved for remote expansion")
    func tildePreserved() {
        #expect(RemoteCommandBuilder.quoteRemotePath("~") == "~")
        #expect(RemoteCommandBuilder.quoteRemotePath("~/code/api") == "~/code/api")
    }

    @Test("tilde path with spaces keeps tilde bare and escapes the rest")
    func tildeWithSpaces() {
        #expect(RemoteCommandBuilder.quoteRemotePath("~/My Proj") == "~/'My Proj'")
    }

    @Test("absolute path with metacharacters is fully quoted")
    func absoluteQuoted() {
        #expect(RemoteCommandBuilder.quoteRemotePath("/a b/c") == "'/a b/c'")
        #expect(RemoteCommandBuilder.quoteRemotePath("/plain/path") == "/plain/path")
    }

    @Test("embedded single quotes are escaped")
    func embeddedSingleQuotes() {
        #expect(RemoteCommandBuilder.quoteRemotePath("/it's here") == "'/it'\\''s here'")
    }

    @Test("dangerous tokens are quoted in the command")
    func dangerousTokens() {
        let command = RemoteCommandBuilder.remoteCommand(
            executable: "echo",
            arguments: ["a; rm -rf /", "$(whoami)", "a|b"],
            workingDirectory: nil
        )
        #expect(command == "echo 'a; rm -rf /' '$(whoami)' 'a|b'")
    }
}
