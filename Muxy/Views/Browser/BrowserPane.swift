import SwiftUI

struct BrowserPane: View {
    let state: BrowserTabState
    let focused: Bool
    let onFocus: () -> Void

    @Environment(AppState.self) private var appState
    @Environment(BrowserHistoryStore.self) private var historyStore
    @Environment(\.overlayActive) private var overlayActive
    @State private var addressFieldFocused = false

    var body: some View {
        VStack(spacing: 0) {
            BrowserToolbar(state: state, addressFieldFocused: $addressFieldFocused)
            BrowserWebView(
                state: state,
                focused: focused && !addressFieldFocused,
                overlayActive: overlayActive,
                appState: appState,
                historyStore: historyStore
            )
            .id(state.profileID)
            .contentShape(Rectangle())
            .onTapGesture { onFocus() }
        }
        .background(MuxyTheme.bg)
        .background(shortcuts)
        .onAppear(perform: focusAddressFieldOnOpen)
    }

    private func focusAddressFieldOnOpen() {
        guard state.shouldFocusAddressOnOpen else { return }
        state.shouldFocusAddressOnOpen = false
        addressFieldFocused = true
    }

    @ViewBuilder
    private var shortcuts: some View {
        if focused {
            Group {
                Button("") { addressFieldFocused = true }
                    .keyboardShortcut("l", modifiers: .command)
                Button("") { state.pendingCommand = .reload }
                    .keyboardShortcut("r", modifiers: .command)
                Button("") { state.pendingCommand = .back }
                    .keyboardShortcut("[", modifiers: .command)
                Button("") { state.pendingCommand = .forward }
                    .keyboardShortcut("]", modifiers: .command)
            }
            .opacity(0)
            .frame(width: 0, height: 0)
            .accessibilityHidden(true)
        }
    }
}
