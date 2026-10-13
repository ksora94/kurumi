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
        // While the popover catches up to a new content height, keep the top still instead of
        // letting SwiftUI center the content in the old frame.
        .frame(minHeight: 0, maxHeight: .infinity, alignment: .top)
    }
}
