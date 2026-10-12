import AppKit
import SwiftUI

struct WatchlistView: View {
    let store: WatchlistStore
    let state: PanelState

    private static let rowHeight: CGFloat = 46
    private static let extendedLineHeight: CGFloat = 15
    private static let maxHeight: CGFloat = 440

    var body: some View {
        List {
            ForEach(store.items) { item in
                let quote = store.quotes[item.symbol]
                WatchRow(item: item, quote: quote, state: state)
                    .frame(height: Self.height(for: quote))
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .contextMenu {
                        Button("在 Yahoo Finance 打开") { openYahoo(item.symbol) }
                        Divider()
                        Button("删除", role: .destructive) { store.remove(item.symbol) }
                    }
            }
            .onMove { store.move(from: $0, to: $1) }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
        .frame(height: listHeight)
    }

    private var listHeight: CGFloat {
        let total = store.items.reduce(0) { $0 + Self.height(for: store.quotes[$1.symbol]) }
        return min(total + 8, Self.maxHeight)
    }

    private static func height(for quote: Quote?) -> CGFloat {
        quote?.extended == nil ? rowHeight : rowHeight + extendedLineHeight
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

    var body: some View {
        VStack(spacing: 2) {
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
                VStack(alignment: .trailing, spacing: 2) {
                    if let move = quote?.regular {
                        Text(Format.price(move.price))
                            .font(.system(size: 13, weight: .medium).monospacedDigit())
                        Text(Format.change(move))
                            .font(.system(size: 11).monospacedDigit())
                            .foregroundStyle(move.color)
                    } else {
                        Text("—")
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            if let extended = quote?.extended {
                HStack(spacing: 4) {
                    Spacer()
                    Text(extended.session.label)
                        .foregroundStyle(.secondary)
                    Text(Format.price(extended.move.price))
                    Text(Format.change(extended.move))
                        .foregroundStyle(extended.move.color)
                }
                .font(.system(size: 10).monospacedDigit())
            }
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovering ? Color.primary.opacity(0.07) : .clear)
                .padding(.horizontal, 4)
        )
        .contentShape(Rectangle())
        .onHover { hovering in
            if hovering {
                state.hoveredSymbol = item.symbol
            } else if isHovering {
                state.hoveredSymbol = nil
            }
        }
        .onTapGesture { openYahoo(item.symbol) }
        .help("点击在浏览器打开，拖动调整顺序，右键删除")
    }
}
