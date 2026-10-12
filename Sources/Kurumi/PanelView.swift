import SwiftUI

struct PanelView: View {
    let store: WatchlistStore
    let state: PanelState

    private var search: SearchModel { state.search }

    var body: some View {
        VStack(spacing: 0) {
            SearchField(
                text: Binding(get: { search.query }, set: { search.query = $0 }),
                placeholder: "搜索美股代码或公司名",
                onMoveSelection: { search.moveSelection(by: $0) },
                onSubmit: addSelected,
                onCancel: {
                    guard search.isActive else { return false }
                    search.clear()
                    return true
                }
            )
            .frame(height: 28)
            .padding(10)

            Divider()

            if search.isActive {
                SuggestionList(search: search, store: store, onPick: add)
            } else if store.items.isEmpty {
                EmptyWatchlist()
            } else {
                WatchlistView(store: store, state: state)
            }

            Divider()
            FooterView(store: store)
        }
        .frame(width: 320)
    }

    private func addSelected() {
        guard let result = search.selected else { return }
        add(result)
    }

    private func add(_ result: SearchResult) {
        guard !store.contains(result.symbol) else { return }
        store.add(result)
        search.clear()
    }
}

private struct EmptyWatchlist: View {
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)
            Text("在上方搜索并添加股票")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
    }
}

private struct FooterView: View {
    let store: WatchlistStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            HStack(spacing: 6) {
                if let lastError = store.lastError {
                    Label(lastError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                } else if let lastUpdated = store.lastUpdated {
                    Text("更新于 \(Format.time(lastUpdated))")
                }
                Spacer()
                if store.periods != nil {
                    let session = store.session(at: context.date)
                    HStack(spacing: 4) {
                        Circle()
                            .fill(session == .regular ? Color.green : session.isActive ? Color.orange : Color.secondary)
                            .frame(width: 6, height: 6)
                        Text(session.label)
                    }
                }
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
        }
    }
}
