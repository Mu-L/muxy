import AppKit
import SwiftUI

struct BrowserAddressField: NSViewRepresentable {
    @Binding var text: String
    @Binding var focused: Bool
    let placeholder: String
    let onSubmit: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> BrowserAddressNSTextField {
        let field = BrowserAddressNSTextField()
        field.delegate = context.coordinator
        field.isBordered = false
        field.drawsBackground = false
        field.focusRingType = .none
        field.font = .systemFont(ofSize: UIMetrics.fontBody)
        field.textColor = NSColor(MuxyTheme.fg)
        field.placeholderString = placeholder
        field.stringValue = text
        field.cell?.sendsActionOnEndEditing = false
        return field
    }

    func updateNSView(_ field: BrowserAddressNSTextField, context: Context) {
        context.coordinator.parent = self

        if field.currentEditor() == nil, field.stringValue != text {
            field.stringValue = text
        }

        guard focused, field.currentEditor() == nil, let window = field.window else { return }
        window.makeFirstResponder(field)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: BrowserAddressField

        init(parent: BrowserAddressField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField else { return }
            parent.text = field.stringValue
        }

        func controlTextDidBeginEditing(_: Notification) {
            guard !parent.focused else { return }
            parent.focused = true
        }

        func controlTextDidEndEditing(_: Notification) {
            guard parent.focused else { return }
            parent.focused = false
        }

        func control(_: NSControl, textView _: NSTextView, doCommandBy selector: Selector) -> Bool {
            guard selector == #selector(NSResponder.insertNewline(_:)) else { return false }
            parent.onSubmit()
            return true
        }
    }
}

final class BrowserAddressNSTextField: NSTextField {
    private var selectsAllOnMouseUp = false

    override func becomeFirstResponder() -> Bool {
        let didBecome = super.becomeFirstResponder()
        guard didBecome else { return false }
        selectsAllOnMouseUp = true
        currentEditor()?.selectAll(nil)
        return true
    }

    override func resignFirstResponder() -> Bool {
        selectsAllOnMouseUp = false
        return super.resignFirstResponder()
    }

    override func mouseDown(with event: NSEvent) {
        super.mouseDown(with: event)
        selectAllIfFocusAcquiringClick()
    }

    func selectAllIfFocusAcquiringClick() {
        guard selectsAllOnMouseUp else { return }
        selectsAllOnMouseUp = false
        guard let editor = currentEditor() as? NSTextView, editor.selectedRange().length == 0 else { return }
        editor.selectAll(nil)
    }
}
