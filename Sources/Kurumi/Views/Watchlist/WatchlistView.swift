import SwiftUI
import UniformTypeIdentifiers

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
                        WatchRow(item: item, quote: store.quotes[item.symbol], state: state) {
                            delete(item.symbol)
                        }
                            .frame(height: Self.rowHeight)
                            .id(item.symbol)
                        .contextMenu {
                            Button("在 Yahoo Finance 打开") { openYahoo(item.symbol) }
                            Divider()
                            Button("删除", role: .destructive) { store.remove(item.symbol) }
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
            .background {
                if state.isSorting {
                    EscapeMonitor { state.endSorting() }
                }
            }
        }
    }

    private func delete(_ symbol: String) {
        withAnimation(.easeOut(duration: 0.2)) { store.remove(symbol) }
        if store.items.isEmpty { state.endSorting() }
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
        state.endDrag()
        return true
    }
}
