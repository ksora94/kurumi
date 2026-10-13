import AppKit
import SwiftUI

extension View {
    /// Shows the pointing-hand cursor over this view, like CSS `cursor: pointer`.
    func pointerCursor() -> some View {
        cursor(.pointingHand)
    }

    /// Shows the given cursor over this view, e.g. `.openHand` for CSS `cursor: grab`.
    func cursor(_ cursor: NSCursor) -> some View {
        overlay(CursorArea(cursor: cursor))
    }
}

/// Uses AppKit cursor rects rather than NSCursor push/pop, so the cursor can't get stuck when
/// the view disappears mid-hover (e.g. the suggestion list closing after a click).
private struct CursorArea: NSViewRepresentable {
    let cursor: NSCursor

    func makeNSView(context: Context) -> CursorView {
        CursorView(cursor: cursor)
    }

    func updateNSView(_ nsView: CursorView, context: Context) {}

    final class CursorView: NSView {
        private let cursor: NSCursor

        init(cursor: NSCursor) {
            self.cursor = cursor
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { nil }

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: cursor)
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
