import Foundation

enum WorkspaceContext: Hashable {
    case local
    case ssh(SSHDestination)

    var isRemote: Bool {
        if case .ssh = self { return true }
        return false
    }

    var sshDestination: SSHDestination? {
        if case let .ssh(destination) = self { return destination }
        return nil
    }
}
