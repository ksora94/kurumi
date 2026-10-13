import SwiftUI

struct SearchPage: View {
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
