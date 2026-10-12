import AppKit
import SwiftUI

extension View {
    /// Shows the pointing-hand cursor over this view, like CSS `cursor: pointer`.
    func pointerCursor() -> some View {
        overlay(PointerCursorArea())
    }
}

/// Uses AppKit cursor rects rather than NSCursor push/pop, so the cursor can't get stuck when
/// the view disappears mid-hover (e.g. the suggestion list closing after a click).
private struct PointerCursorArea: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView { CursorView() }
    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class CursorView: NSView {
        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .pointingHand)
        }

        override func hitTest(_ point: NSPoint) -> NSView? { nil }
    }
}
