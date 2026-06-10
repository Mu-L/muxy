import Foundation

@MainActor
@Observable
final class ActiveWorkspaceContext {
    static let shared = ActiveWorkspaceContext()

    private(set) var current: WorkspaceContext = .local

    func update(_ context: WorkspaceContext) {
        guard context != current else { return }
        current = context
    }
}
