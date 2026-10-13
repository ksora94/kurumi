import AppKit
import SwiftUI

/// Popovers often don't put SwiftUI in the key responder chain, so Escape is also watched here.
struct EscapeMonitor: NSViewRepresentable {
    let onEscape: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak coordinator = context.coordinator] event in
            if event.keyCode == 53 {
                coordinator?.onEscape()
                return nil
            }
            return event
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onEscape = onEscape
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        if let monitor = coordinator.monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onEscape: onEscape) }

    final class Coordinator {
        var onEscape: () -> Void
        var monitor: Any?

        init(onEscape: @escaping () -> Void) {
            self.onEscape = onEscape
        }
    }
}
