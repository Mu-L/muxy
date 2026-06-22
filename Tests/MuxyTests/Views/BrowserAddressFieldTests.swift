import AppKit
import SwiftUI
import Testing

@testable import Muxy

@MainActor
@Suite("BrowserAddressField")
struct BrowserAddressFieldTests {
    @Test("selects all text when focus is requested")
    func selectsAllTextWhenFocusIsRequested() async throws {
        let model = BrowserAddressFieldModel(text: "https://muxy.app/docs")
        let hostingView = NSHostingView(rootView: BrowserAddressFieldHarness(model: model))
        hostingView.frame = NSRect(x: 0, y: 0, width: 360, height: 32)
        hostingView.layoutSubtreeIfNeeded()

        let field = try #require(textField(in: hostingView))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 120),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil) }

        model.focused = true

        let selectedRange = try await selectedRange(in: field)
        #expect(selectedRange == NSRange(location: 0, length: model.text.utf16.count))
    }

    @Test("click focus selects all text")
    func clickFocusSelectsAllText() async throws {
        let model = BrowserAddressFieldModel(text: "https://example.com/path")
        let hostingView = NSHostingView(rootView: BrowserAddressFieldHarness(model: model))
        hostingView.frame = NSRect(x: 0, y: 0, width: 360, height: 32)
        hostingView.layoutSubtreeIfNeeded()

        let field = try #require(textField(in: hostingView))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 120),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil) }

        window.makeFirstResponder(field)

        let selectedRange = try await selectedRange(in: field)
        #expect(selectedRange == NSRange(location: 0, length: model.text.utf16.count))
    }

    @Test("mouse click selects all text on focus acquisition")
    func mouseClickSelectsAllText() async throws {
        let model = BrowserAddressFieldModel(text: "https://example.com/path")
        let hostingView = NSHostingView(rootView: BrowserAddressFieldHarness(model: model))
        hostingView.frame = NSRect(x: 0, y: 0, width: 360, height: 32)
        hostingView.layoutSubtreeIfNeeded()

        let field = try #require(textField(in: hostingView))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 120),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil) }

        try clickToFocus(field, in: window, collapseCaret: true)

        let selectedRange = try await selectedRange(in: field)
        #expect(selectedRange == NSRange(location: 0, length: model.text.utf16.count))
    }

    @Test("mouse drag selection is preserved")
    func mouseDragSelectionIsPreserved() async throws {
        let model = BrowserAddressFieldModel(text: "https://example.com/path")
        let hostingView = NSHostingView(rootView: BrowserAddressFieldHarness(model: model))
        hostingView.frame = NSRect(x: 0, y: 0, width: 360, height: 32)
        hostingView.layoutSubtreeIfNeeded()

        let field = try #require(textField(in: hostingView))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 120),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil) }

        let dragRange = NSRange(location: 0, length: 4)
        try clickToFocus(field, in: window, dragSelection: dragRange)

        let editor = try #require(field.currentEditor() as? NSTextView)
        #expect(editor.selectedRange() == dragRange)
    }

    @Test("typing keeps focus and does not reset the text")
    func typingKeepsFocus() async throws {
        let model = BrowserAddressFieldModel(text: "")
        let hostingView = NSHostingView(rootView: BrowserAddressFieldHarness(model: model))
        hostingView.frame = NSRect(x: 0, y: 0, width: 360, height: 32)
        hostingView.layoutSubtreeIfNeeded()

        let field = try #require(textField(in: hostingView))
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 120),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        window.contentView = hostingView
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil) }

        window.makeFirstResponder(field)
        let editor = try #require(field.currentEditor() as? NSTextView)

        editor.insertText("g", replacementRange: editor.selectedRange())
        editor.insertText("h", replacementRange: editor.selectedRange())

        hostingView.layoutSubtreeIfNeeded()

        #expect(field.currentEditor() === editor)
        #expect(window.firstResponder === editor)
        #expect(model.focused)
        #expect(field.stringValue == "gh")
    }

    private func clickToFocus(
        _ field: NSTextField,
        in window: NSWindow,
        collapseCaret: Bool = false,
        dragSelection: NSRange? = nil
    ) throws {
        let addressField = try #require(field as? BrowserAddressNSTextField)
        window.makeFirstResponder(addressField)
        let editor = try #require(addressField.currentEditor() as? NSTextView)
        if collapseCaret {
            editor.setSelectedRange(NSRange(location: editor.string.utf16.count, length: 0))
        }
        if let dragSelection {
            editor.setSelectedRange(dragSelection)
        }
        addressField.selectAllIfFocusAcquiringClick()
    }

    private func selectedRange(in field: NSTextField) async throws -> NSRange {
        for _ in 0..<40 {
            if let selectedRange = (field.currentEditor() as? NSTextView)?.selectedRange(),
               selectedRange.length == field.stringValue.utf16.count {
                return selectedRange
            }
            try await Task.sleep(for: .milliseconds(20))
        }
        return try #require((field.currentEditor() as? NSTextView)?.selectedRange())
    }

    private func textField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField {
            return field
        }
        for subview in view.subviews {
            if let field = textField(in: subview) {
                return field
            }
        }
        return nil
    }
}

@MainActor
private final class BrowserAddressFieldModel: ObservableObject {
    @Published var text: String
    @Published var focused = false

    init(text: String) {
        self.text = text
    }
}

private struct BrowserAddressFieldHarness: View {
    @ObservedObject var model: BrowserAddressFieldModel

    var body: some View {
        BrowserAddressField(
            text: $model.text,
            focused: $model.focused,
            placeholder: "Search or enter address"
        ) {}
        .frame(width: 360, height: 32)
    }
}
