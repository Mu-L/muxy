import Foundation

struct SSHDestination: Hashable, Codable {
    var host: String
    var remoteRoot: String
    var port: Int?
    var user: String?
    var identityFile: String?

    init(
        host: String,
        remoteRoot: String = "~",
        port: Int? = nil,
        user: String? = nil,
        identityFile: String? = nil
    ) {
        self.host = host
        let trimmedRoot = remoteRoot.trimmingCharacters(in: .whitespacesAndNewlines)
        self.remoteRoot = trimmedRoot.isEmpty ? "~" : trimmedRoot
        self.port = port
        self.user = user.flatMap { $0.isEmpty ? nil : $0 }
        self.identityFile = identityFile.flatMap { $0.isEmpty ? nil : $0 }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        host = try container.decode(String.self, forKey: .host)
        remoteRoot = try container.decodeIfPresent(String.self, forKey: .remoteRoot) ?? "~"
        port = try container.decodeIfPresent(Int.self, forKey: .port)
        user = try container.decodeIfPresent(String.self, forKey: .user)
        identityFile = try container.decodeIfPresent(String.self, forKey: .identityFile)
    }

    var target: String {
        guard let user else { return host }
        return "\(user)@\(host)"
    }

    var connectionArguments: [String] {
        var arguments: [String] = []
        if let port {
            arguments += ["-p", String(port)]
        }
        if let identityFile {
            arguments += ["-i", identityFile, "-o", "IdentitiesOnly=yes"]
        }
        return arguments
    }

    private static let keepAliveOptions: [String] = [
        "-o", "ConnectTimeout=8",
        "-o", "ServerAliveInterval=15",
        "-o", "ServerAliveCountMax=3",
    ]

    private static let multiplexOptions: [String] = [
        "-o", "ControlMaster=auto",
        "-o", "ControlPath=~/.ssh/muxy-%C",
        "-o", "ControlPersist=120",
    ]

    static let batchOptions: [String] = ["-o", "BatchMode=yes"] + multiplexOptions + keepAliveOptions

    static let connectOptions: [String] = multiplexOptions + keepAliveOptions

    static let terminalOptions: [String] = ["-o", "ControlMaster=no"] + keepAliveOptions
}
