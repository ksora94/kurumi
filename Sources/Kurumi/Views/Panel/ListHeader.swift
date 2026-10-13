import SwiftUI

struct ListHeader: View {
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
