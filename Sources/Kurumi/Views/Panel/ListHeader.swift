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
