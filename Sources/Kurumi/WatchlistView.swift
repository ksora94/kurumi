import AppKit
import SwiftUI
import UniformTypeIdentifiers

/// Gap between row blocks and the panel edges / dividers.
let panelContentInset: CGFloat = 4
let panelRowSpacing: CGFloat = 4

/// A ScrollView rather than List: List adds its own insets (including room for the scroller)
/// that can't be controlled, which breaks the even margins around the rows.
struct WatchlistView: View {
    let store: WatchlistStore
    let state: PanelState

    private static let rowHeight: CGFloat = 46
    private static let maxHeight: CGFloat = 440

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: panelRowSpacing) {
                    ForEach(store.items) { item in
                        WatchRow(item: item, quote: store.quotes[item.symbol], state: state)
                            .frame(height: Self.rowHeight)
                            .id(item.symbol)
                            .contextMenu {
                                Button("在 Yahoo Finance 打开") { openYahoo(item.symbol) }
                                Divider()
                                Button("删除", role: .destructive) { store.remove(item.symbol) }
                            }
                            .onDrag {
                                state.draggingSymbol = item.symbol
                                return NSItemProvider(object: item.symbol as NSString)
                            }
                            .onDrop(of: [.text], delegate: ReorderDropDelegate(target: item.symbol, store: store, state: state))
                    }
                }
                .padding(panelContentInset)
            }
            .scrollIndicators(.automatic)
            .frame(height: listHeight)
            .onAppear {
                if let symbol = state.recentlyAdded {
                    proxy.scrollTo(symbol, anchor: .bottom)
                }
            }
        }
    }

    private var listHeight: CGFloat {
        let count = CGFloat(store.items.count)
        let content = count * Self.rowHeight + max(count - 1, 0) * panelRowSpacing + panelContentInset * 2
        return min(content, Self.maxHeight)
    }
}

/// Reorders live while hovering over other rows, like List's onMove.
private struct ReorderDropDelegate: DropDelegate {
    let target: String
    let store: WatchlistStore
    let state: PanelState

    func dropEntered(info: DropInfo) {
        guard let dragging = state.draggingSymbol, dragging != target,
              let from = store.items.firstIndex(where: { $0.symbol == dragging }),
              let to = store.items.firstIndex(where: { $0.symbol == target })
        else { return }
        withAnimation(.easeInOut(duration: 0.15)) {
            store.move(from: IndexSet(integer: from), to: to > from ? to + 1 : to)
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func performDrop(info: DropInfo) -> Bool {
        state.draggingSymbol = nil
        return true
    }
}

func openYahoo(_ symbol: String) {
    guard let url = URL(string: "https://finance.yahoo.com/quote/\(symbol)") else { return }
    NSWorkspace.shared.open(url)
}

private struct WatchRow: View {
    let item: WatchItem
    let quote: Quote?
    let state: PanelState

    private var isHovering: Bool { state.hoveredSymbol == item.symbol }
    private var isHighlighted: Bool { state.recentlyAdded == item.symbol }

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.symbol)
                    .font(.system(size: 13, weight: .semibold))
                Text(item.name)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 3) {
                if let move = quote?.regular {
                    PriceLine(move: move)
                    if let extended = quote?.extended {
                        HStack(spacing: 4) {
                            Text(extended.session.label)
                                .foregroundStyle(.secondary)
                            Text(Format.price(extended.move.price))
                            Text(Format.percent(extended.move))
                                .foregroundStyle(extended.move.color)
                        }
                        .font(.system(size: 10).monospacedDigit())
                    }
                } else {
                    Text("—")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            .fixedSize()
        }
        .padding(.horizontal, 10)
        .frame(maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 6).fill(background))
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                state.hoveredSymbol = item.symbol
            } else if isHovering {
                state.hoveredSymbol = nil
            }
        }
    }

    private var background: Color {
        if isHighlighted { return Color.accentColor.opacity(0.2) }
        if isHovering { return Color.primary.opacity(0.07) }
        return .clear
    }
}

/// Price followed by the colored change pill; shared by watchlist rows and search suggestions.
struct PriceLine: View {
    let move: PriceMove

    var body: some View {
        HStack(spacing: 8) {
            Text(Format.price(move.price))
                .font(.system(size: 13, weight: .medium).monospacedDigit())
            ChangePill(move: move)
        }
    }
}

private struct ChangePill: View {
    let move: PriceMove

    var body: some View {
        Text(Format.percent(move))
            .font(.system(size: 11, weight: .semibold).monospacedDigit())
            .foregroundStyle(.white)
            .lineLimit(1)
            .frame(minWidth: 46)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4).fill(fill))
    }

    private var fill: Color {
        if move.change > 0 { return .green }
        if move.change < 0 { return .red }
        return .gray
    }
}
