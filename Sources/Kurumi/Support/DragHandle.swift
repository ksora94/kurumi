import AppKit
import SwiftUI

/// Transparent AppKit layer over a row's drag handle that starts a native dragging session.
/// SwiftUI's onDrag always centers its preview on the cursor and has no end callback; a native
/// session lets the preview start exactly over the row, slide back on cancel, and report its end.
struct DragHandle<Preview: View>: NSViewRepresentable {
    let symbol: String
    /// Size of the whole row; the handle sits at the row's leading edge, full height.
    let rowWidth: CGFloat
    let preview: () -> Preview
    let onBegin: () -> Void
    let onEnd: () -> Void

    func makeNSView(context: Context) -> HandleView {
        let view = HandleView()
        update(view)
        return view
    }

    func updateNSView(_ view: HandleView, context: Context) {
        update(view)
    }

    private func update(_ view: HandleView) {
        view.symbol = symbol
        view.rowWidth = rowWidth
        view.makePreview = { AnyView(preview()) }
        view.onBegin = onBegin
        view.onEnd = onEnd
    }

    final class HandleView: NSView, NSDraggingSource {
        var symbol = ""
        var rowWidth: CGFloat = 0
        var makePreview: () -> AnyView = { AnyView(EmptyView()) }
        var onBegin: () -> Void = {}
        var onEnd: () -> Void = {}

        private var mouseDownPoint: NSPoint?

        override func resetCursorRects() {
            addCursorRect(bounds, cursor: .openHand)
        }

        override func mouseDown(with event: NSEvent) {
            mouseDownPoint = convert(event.locationInWindow, from: nil)
        }

        override func mouseUp(with event: NSEvent) {
            mouseDownPoint = nil
        }

        override func mouseDragged(with event: NSEvent) {
            guard let start = mouseDownPoint else { return }
            let point = convert(event.locationInWindow, from: nil)
            guard hypot(point.x - start.x, point.y - start.y) > 3 else { return }
            mouseDownPoint = nil

            let item = NSDraggingItem(pasteboardWriter: symbol as NSString)
            let rowFrame = NSRect(x: 0, y: 0, width: rowWidth, height: bounds.height)
            item.setDraggingFrame(rowFrame, contents: renderPreview(size: rowFrame.size))

            let session = beginDraggingSession(with: [item], event: event, source: self)
            session.animatesToStartingPositionsOnCancelOrFail = true
            onBegin()
        }

        func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
            context == .withinApplication ? .move : []
        }

        func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
            onEnd()
        }

        private func renderPreview(size: CGSize) -> NSImage? {
            let appearance = window?.effectiveAppearance ?? NSApp.effectiveAppearance
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let renderer = ImageRenderer(
                content: makePreview()
                    .frame(width: size.width, height: size.height)
                    .environment(\.colorScheme, isDark ? .dark : .light)
            )
            renderer.scale = window?.backingScaleFactor ?? 2
            var image: NSImage?
            appearance.performAsCurrentDrawingAppearance { image = renderer.nsImage }
            return image
        }
    }
}
