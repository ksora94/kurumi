import AppKit
import Observation
import SwiftUI

/// Cycles the status item through the watchlist, one colored tag at a time, sliding each new
/// tag in from below. Falls back to the app icon when there's nothing to show.
@MainActor
final class MenuBarTicker: NSObject {
    private struct Entry: Equatable {
        let symbol: String
        let move: PriceMove
    }

    private static let interval: Duration = .seconds(5)
    /// Space between the tag and the edges of the status item.
    private static let horizontalMargin: CGFloat = 4

    private let statusItem: NSStatusItem
    private let store: WatchlistStore
    private let icon: NSImage
    private var index = 0
    private var isHovering = false
    private var cycleTask: Task<Void, Never>?

    init(statusItem: NSStatusItem, store: WatchlistStore, icon: NSImage) {
        self.statusItem = statusItem
        self.store = store
        self.icon = icon
        super.init()
    }

    func start() {
        guard let button = statusItem.button else { return }
        button.wantsLayer = true
        button.layer?.masksToBounds = true
        button.imagePosition = .imageOnly
        button.addTrackingArea(NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        ))
        observeStore()
        render(animated: false)
        restartCycle()
    }

    @objc func mouseEntered(with event: NSEvent) {
        isHovering = true
        cycleTask?.cancel()
    }

    @objc func mouseExited(with event: NSEvent) {
        isHovering = false
        restartCycle()
    }

    private var entries: [Entry] {
        store.items.compactMap { item in
            store.quotes[item.symbol].map { Entry(symbol: item.symbol, move: $0.latestMove) }
        }
    }

    private func observeStore() {
        withObservationTracking {
            _ = entries
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.render(animated: false)
                self?.observeStore()
            }
        }
    }

    private func restartCycle() {
        cycleTask?.cancel()
        cycleTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.interval)
                guard !Task.isCancelled, let self, !self.isHovering else { return }
                let count = self.entries.count
                guard count > 1 else { continue }
                self.index = (self.index + 1) % count
                self.render(animated: true)
            }
        }
    }

    private func render(animated: Bool) {
        guard let button = statusItem.button else { return }
        let entries = entries
        guard !entries.isEmpty else {
            button.title = ""
            button.image = icon
            button.imagePosition = .imageOnly
            statusItem.length = NSStatusItem.squareLength
            return
        }

        index %= entries.count
        // Price tags share the widest tag's width, and the item is sized for the widest symbol,
        // so neighbouring menu bar items never shift while cycling.
        let tagWidth = entries.compactMap { Self.render(TickerTag(entry: $0, width: nil))?.size.width }.max() ?? 0
        guard let image = Self.render(TickerTag(entry: entries[index], width: ceil(tagWidth))) else { return }
        let symbolWidth = entries.map { Self.symbolWidth($0.symbol) }.max() ?? 0

        let length = ceil(symbolWidth + image.size.width) + Self.horizontalMargin * 2
        if statusItem.length != length { statusItem.length = length }
        button.font = Self.symbolFont
        button.imagePosition = .imageTrailing

        if animated, let layer = button.layer {
            let transition = CATransition()
            transition.type = .push
            transition.subtype = .fromBottom
            transition.duration = 0.35
            transition.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.add(transition, forKey: "tick")
        }
        button.title = entries[index].symbol
        button.image = image
    }

    /// The symbol is the button's own title so it follows the menu bar's text color.
    private static let symbolFont = NSFont.systemFont(ofSize: 12, weight: .medium)

    private static func symbolWidth(_ symbol: String) -> CGFloat {
        NSAttributedString(string: symbol, attributes: [.font: symbolFont]).size().width
    }

    private static func render(_ tag: TickerTag) -> NSImage? {
        let renderer = ImageRenderer(content: tag)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2
        return renderer.nsImage
    }

    /// The price in white on a red / green rounded tag.
    private struct TickerTag: View {
        let entry: Entry
        let width: CGFloat?

        private static let height = min(NSStatusBar.system.thickness - 8, 16)
        /// Transparent gap between the symbol title and the tag.
        private static let leadingGap: CGFloat = 4

        var body: some View {
            Text(Format.price(entry.move.price))
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundStyle(.white)
                .lineLimit(1)
                .padding(.horizontal, 4)
                .frame(width: width.map { $0 - Self.leadingGap }, height: Self.height)
                .background(RoundedRectangle(cornerRadius: 4).fill(fill))
                .padding(.leading, Self.leadingGap)
        }

        private var fill: Color {
            if entry.move.change > 0 { return .green }
            if entry.move.change < 0 { return .red }
            return .gray
        }
    }
}
