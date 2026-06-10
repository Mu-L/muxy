import Foundation
import Testing

@testable import Muxy

@Suite("ProjectGroup decoding and migration")
struct ProjectGroupMigrationTests {
    private func decode(_ json: String) throws -> ProjectGroup {
        try JSONDecoder().decode(ProjectGroup.self, from: Data(json.utf8))
    }

    @Test("legacy rows backfill to local with no remote data")
    func legacyBackfill() throws {
        let json = """
        {
          "id": "00000000-0000-0000-0000-000000000001",
          "name": "Personal",
          "sortOrder": 2,
          "projectIDs": ["00000000-0000-0000-0000-0000000000AA"]
        }
        """
        let group = try decode(json)
        #expect(group.type == .local)
        #expect(group.sshData == nil)
        #expect(group.remoteProjects.isEmpty)
        #expect(group.workspaceContext == .local)
    }

    @Test("ssh rows round-trip with destination and remote projects")
    func sshRoundTrip() throws {
        let original = ProjectGroup(
            name: "prod",
            sortOrder: 1,
            type: .ssh,
            sshData: SSHWorkspaceData(host: "prod", remoteRoot: "~/code"),
            remoteProjects: [RemoteProject(name: "api", path: "~/code/api")]
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ProjectGroup.self, from: data)
        #expect(decoded.type == .ssh)
        #expect(decoded.sshData?.host == "prod")
        #expect(decoded.remoteProjects.first?.path == "~/code/api")
        #expect(decoded.workspaceContext == .ssh(SSHDestination(host: "prod", remoteRoot: "~/code")))
    }

    @Test("empty remote root defaults to home")
    func emptyRootDefaults() {
        let data = SSHWorkspaceData(host: "prod", remoteRoot: "  ")
        #expect(data.remoteRoot == "~")
    }
}
