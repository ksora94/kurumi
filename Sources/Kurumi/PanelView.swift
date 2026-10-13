import SwiftUI

struct PanelView: View {
    let store: WatchlistStore
    let state: PanelState

    var body: some View {
        VStack(spacing: 0) {
            if state.isShowingDetail {
                DetailView(store: store, state: state)
            } else if state.isSearching {
                SearchPage(store: store, state: state)
            } else {
                ListHeader(state: state, canSort: !store.items.isEmpty)
                Divider()
                if store.items.isEmpty {
                    EmptyWatchlist(onAdd: state.openSearch)
                } else {
                    WatchlistView(store: store, state: state)
                }
            }

            Divider()
            FooterView(store: store)
        }
        .frame(width: panelWidth)
    }
}

/// "返回" button shared by the search and detail page headers.
struct BackButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                Text("返回")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.secondary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }
}

/// Shared by the list header and the footer so both bars have the same height.
private let panelBarHeight: CGFloat = 28

private struct ListHeader: View {
    let state: PanelState
    let canSort: Bool

    var body: some View {
        HStack(spacing: 8) {
            if canSort {
                HeaderIconButton(
                    systemName: "arrow.up.arrow.down",
                    size: 11,
                    isActive: state.isSorting,
                    action: state.toggleSorting
                )
            }
            Spacer()
            if !state.isSorting {
                HeaderIconButton(systemName: "plus.circle", action: state.openSearch)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: panelBarHeight)
    }
}

private struct HeaderIconButton: View {
    let systemName: String
    /// Glyphs differ in visual weight; this lets them read as the same size.
    var size: CGFloat = 13
    var isActive = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(isActive ? Color.accentColor : Color.secondary)
                .frame(width: 22, height: 20)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isActive ? Color.accentColor.opacity(0.15) : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }
}

private struct SearchPage: View {
    let store: WatchlistStore
    let state: PanelState

    private var search: SearchModel { state.search }

    var body: some View {
        HStack(spacing: 10) {
            BackButton(action: state.closeSearch)
            SearchField(
                text: Binding(get: { search.query }, set: { search.query = $0 }),
                placeholder: "搜索美股代码或公司名",
                onMoveSelection: { search.moveSelection(by: $0) },
                onSubmit: addSelected,
                onCancel: {
                    if search.isActive {
                        search.clear()
                    } else {
                        state.closeSearch()
                    }
                    return true
                }
            )
            .frame(height: 28)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)

        Divider()

        if search.isActive {
            SuggestionList(search: search, store: store, onPick: add)
        } else {
            Text("输入代码或公司名称")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
        }
    }

    private func addSelected() {
        guard let result = search.selected else { return }
        add(result)
    }

    private func add(_ result: SearchResult) {
        guard !store.contains(result.symbol) else { return }
        store.add(result)
        state.markAdded(result.symbol)
        state.closeSearch()
    }
}

private struct EmptyWatchlist: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)
            Text("还没有自选股票")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Button("添加股票", action: onAdd)
                .controlSize(.small)
                .pointerCursor()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
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
            .frame(height: panelBarHeight)
        }
    }
}
