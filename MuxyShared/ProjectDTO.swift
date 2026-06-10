import Foundation

public enum WorkspaceKindDTO: String, Codable, Hashable, Sendable {
    case local
    case ssh
}

public struct ProjectDTO: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var path: String
    public var sortOrder: Int
    public var createdAt: Date
    public var icon: String?
    public var logo: String?
    public var iconColor: String?
    public var preferredWorktreeParentPath: String?
    public var worktreesEnabled: Bool
    public var workspaceID: UUID?
    public var workspaceName: String?
    public var workspaceKind: WorkspaceKindDTO

    public init(
        id: UUID,
        name: String,
        path: String,
        sortOrder: Int,
        createdAt: Date,
        icon: String? = nil,
        logo: String? = nil,
        iconColor: String? = nil,
        preferredWorktreeParentPath: String? = nil,
        worktreesEnabled: Bool = false,
        workspaceID: UUID? = nil,
        workspaceName: String? = nil,
        workspaceKind: WorkspaceKindDTO = .local
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.sortOrder = sortOrder
        self.createdAt = createdAt
        self.icon = icon
        self.logo = logo
        self.iconColor = iconColor
        self.preferredWorktreeParentPath = preferredWorktreeParentPath
        self.worktreesEnabled = worktreesEnabled
        self.workspaceID = workspaceID
        self.workspaceName = workspaceName
        self.workspaceKind = workspaceKind
    }
}
