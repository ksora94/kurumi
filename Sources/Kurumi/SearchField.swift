import AppKit
import SwiftUI

extension Notification.Name {
    static let kurumiPanelDidShow = Notification.Name("KurumiPanelDidShow")
}

/// NSSearchField wrapper, since SwiftUI's TextField doesn't reliably hand arrow keys to us.
struct SearchField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onMoveSelection: (Int) -> Void
    var onSubmit: () -> Void
    /// Returns true when Escape was handled; otherwise it falls through and closes the popover.
    var onCancel: () -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSSearchField {
        let field = NSSearchField()
        field.placeholderString = placeholder
        field.delegate = context.coordinator
        field.focusRingType = .none
        field.bezelStyle = .roundedBezel
        field.controlSize = .large
        field.sendsSearchStringImmediately = true
        context.coordinator.field = field
        return field
    }

    func updateNSView(_ field: NSSearchField, context: Context) {
        context.coordinator.parent = self
        if field.stringValue != text {
            field.stringValue = text
        }
    }

    final class Coordinator: NSObject, NSSearchFieldDelegate {
        var parent: SearchField
        weak var field: NSSearchField?
        private var observer: NSObjectProtocol?

        init(_ parent: SearchField) {
            self.parent = parent
            super.init()
            observer = NotificationCenter.default.addObserver(
                forName: .kurumiPanelDidShow, object: nil, queue: .main
            ) { [weak self] _ in
                guard let field = self?.field else { return }
                field.window?.makeFirstResponder(field)
            }
        }

        deinit {
            if let observer { NotificationCenter.default.removeObserver(observer) }
        }

        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSSearchField else { return }
            parent.text = field.stringValue
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.moveUp(_:)):
                parent.onMoveSelection(-1)
                return true
            case #selector(NSResponder.moveDown(_:)):
                parent.onMoveSelection(1)
                return true
            case #selector(NSResponder.insertNewline(_:)):
                parent.onSubmit()
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                return parent.onCancel()
            default:
                return false
            }
        }
    }
}
