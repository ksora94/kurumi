import AppKit
import SwiftUI

extension View {
    /// Thin overlay scrollers that only appear while scrolling or while the pointer moves over
    /// the scroll view, even when the system shows legacy scroll bars (e.g. with a mouse attached).
    /// Apply to the content inside a `ScrollView`.
    func overlayScrollers() -> some View {
        background(OverlayScrollerConfigurator())
    }
}

private struct OverlayScrollerConfigurator: NSViewRepresentable {
    func makeNSView(context: Context) -> ConfiguratorView { ConfiguratorView() }
    func updateNSView(_ nsView: ConfiguratorView, context: Context) {}
}

private final class ConfiguratorView: NSView {
    private weak var scrollView: NSScrollView?
    private var trackingArea: NSTrackingArea?
    private var styleObserver: NSObjectProtocol?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard window != nil else { return detach() }
        // The enclosing scroll view isn't reachable until SwiftUI finishes building the hierarchy.
        DispatchQueue.main.async { [weak self] in self?.attach() }
    }

    private func attach() {
        guard let scrollView = enclosingScrollView, scrollView !== self.scrollView else { return }
        detach()
        self.scrollView = scrollView
        applyStyle()

        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
            owner: self
        )
        scrollView.addTrackingArea(area)
        trackingArea = area

        // NSScrollView resets its style to the system preference whenever that preference changes.
        styleObserver = NotificationCenter.default.addObserver(
            forName: NSScroller.preferredScrollerStyleDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async { self?.applyStyle() }
        }
    }

    private func detach() {
        if let trackingArea { scrollView?.removeTrackingArea(trackingArea) }
        if let styleObserver { NotificationCenter.default.removeObserver(styleObserver) }
        trackingArea = nil
        styleObserver = nil
        scrollView = nil
    }

    private func applyStyle() {
        guard let scrollView else { return }
        scrollView.scrollerStyle = .overlay
        scrollView.verticalScroller?.controlSize = .small
    }

    override func mouseEntered(with event: NSEvent) {
        scrollView?.flashScrollers()
    }

    override func mouseMoved(with event: NSEvent) {
        scrollView?.flashScrollers()
    }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }
}
