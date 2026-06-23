import Foundation

@MainActor
@Observable
final class BrowserSuggestionModel {
    var suggestions: [BrowserHistoryEntry] = []
    var selectedIndex: Int?

    var isEmpty: Bool { suggestions.isEmpty }

    var selectedEntry: BrowserHistoryEntry? {
        guard let selectedIndex, suggestions.indices.contains(selectedIndex) else { return nil }
        return suggestions[selectedIndex]
    }

    func update(_ entries: [BrowserHistoryEntry]) {
        suggestions = entries
        selectedIndex = nil
    }

    func clear() {
        suggestions = []
        selectedIndex = nil
    }

    func moveSelection(_ delta: Int) {
        guard !suggestions.isEmpty else { return }
        let current = selectedIndex ?? (delta > 0 ? -1 : 0)
        let next = current + delta
        guard suggestions.indices.contains(next) else {
            selectedIndex = nil
            return
        }
        selectedIndex = next
    }
}
