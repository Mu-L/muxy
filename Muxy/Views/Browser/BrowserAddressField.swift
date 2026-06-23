import AppKit
import SwiftUI

struct BrowserAddressField: NSViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    let model: BrowserSuggestionModel
    let suggestionsProvider: (String) -> [BrowserHistoryEntry]
    let onSubmit: (BrowserHistoryEntry?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(
            text: $text,
            isFocused: $isFocused,
            model: model,
            suggestionsProvider: suggestionsProvider,
            onSubmit: onSubmit
        )
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField()
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: UIMetrics.fontBody)
        field.textColor = MuxyTheme.nsFg
        field.delegate = context.coordinator
        field.target = context.coordinator
        field.action = #selector(Coordinator.handleSubmit)
        field.placeholderAttributedString = NSAttributedString(
            string: "Search or enter address",
            attributes: [
                .foregroundColor: MuxyTheme.nsFgMuted,
                .font: NSFont.systemFont(ofSize: UIMetrics.fontBody),
            ]
        )
        context.coordinator.field = field
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        if field.stringValue != text, !context.coordinator.isEditing {
            field.stringValue = text
        }
        context.coordinator.applyFocus(isFocused)
    }

    static func dismantleNSView(_: NSTextField, coordinator: Coordinator) {
        coordinator.tearDown()
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        private let text: Binding<String>
        private let isFocused: Binding<Bool>
        private let model: BrowserSuggestionModel
        private let suggestionsProvider: (String) -> [BrowserHistoryEntry]
        private let onSubmit: (BrowserHistoryEntry?) -> Void

        weak var field: NSTextField?
        private(set) var isEditing = false
        private var panel: BrowserSuggestionPanel?
        private var clickMonitor: Any?

        init(
            text: Binding<String>,
            isFocused: Binding<Bool>,
            model: BrowserSuggestionModel,
            suggestionsProvider: @escaping (String) -> [BrowserHistoryEntry],
            onSubmit: @escaping (BrowserHistoryEntry?) -> Void
        ) {
            self.text = text
            self.isFocused = isFocused
            self.model = model
            self.suggestionsProvider = suggestionsProvider
            self.onSubmit = onSubmit
        }

        func applyFocus(_ shouldFocus: Bool) {
            guard let field else { return }
            let isFirstResponder = field.currentEditor() != nil
            guard shouldFocus != isFirstResponder else { return }
            if shouldFocus {
                field.window?.makeFirstResponder(field)
            } else if isFirstResponder {
                field.window?.makeFirstResponder(nil)
            }
        }

        func controlTextDidBeginEditing(_: Notification) {
            isEditing = true
            isFocused.wrappedValue = true
            field?.currentEditor()?.selectAll(nil)
            refreshSuggestions()
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            text.wrappedValue = field.stringValue
            refreshSuggestions()
        }

        func controlTextDidEndEditing(_: Notification) {
            isEditing = false
            isFocused.wrappedValue = false
            dismissSuggestions()
        }

        func control(_: NSControl, textView _: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.moveDown(_:)):
                guard !model.isEmpty else { return false }
                model.moveSelection(1)
                return true
            case #selector(NSResponder.moveUp(_:)):
                guard !model.isEmpty else { return false }
                model.moveSelection(-1)
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                guard panel?.isVisible == true else { return false }
                dismissSuggestions()
                return true
            default:
                return false
            }
        }

        @objc
        func handleSubmit() {
            let selected = model.selectedEntry
            dismissSuggestions()
            onSubmit(selected)
        }

        private func refreshSuggestions() {
            guard let field else { return }
            let entries = suggestionsProvider(field.stringValue)
            model.update(entries)
            guard !entries.isEmpty else {
                dismissSuggestions()
                return
            }
            presentSuggestionsIfNeeded()
        }

        private func presentSuggestionsIfNeeded() {
            guard let field else { return }
            let panel = panel ?? makePanel()
            self.panel = panel
            panel.show(below: field, horizontalInset: UIMetrics.spacing4, verticalGap: UIMetrics.spacing2)
            installClickMonitorIfNeeded()
        }

        private func makePanel() -> BrowserSuggestionPanel {
            BrowserSuggestionPanel(model: model) { [weak self] entry in
                self?.accept(entry)
            }
        }

        private func accept(_ entry: BrowserHistoryEntry) {
            dismissSuggestions()
            onSubmit(entry)
        }

        private func dismissSuggestions() {
            model.clear()
            panel?.hide()
            removeClickMonitor()
        }

        private func installClickMonitorIfNeeded() {
            guard clickMonitor == nil else { return }
            clickMonitor = NSEvent.addLocalMonitorForEvents(
                matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
            ) { [weak self] event in
                self?.handleGlobalClick(event)
                return event
            }
        }

        private func handleGlobalClick(_ event: NSEvent) {
            guard let panel, panel.isVisible else { return }
            if event.window == field?.window || event.window?.parent == field?.window { return }
            dismissSuggestions()
        }

        private func removeClickMonitor() {
            guard let clickMonitor else { return }
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }

        func tearDown() {
            dismissSuggestions()
            panel = nil
        }
    }
}
