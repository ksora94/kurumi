import SwiftUI

/// In sort mode the row shows a handle on the left and a delete button on the right; the whole
/// row (minus the delete button) becomes the drag source and no longer opens the detail page.
struct WatchRow: View {
    let item: WatchItem
    let quote: Quote?
    let state: PanelState
    let onDelete: () -> Void

    private static let contentInset: CGFloat = 10
    private static let handleWidth: CGFloat = 26
    private static let deleteWidth: CGFloat = 30

    private var isSorting: Bool { state.isSorting }
    private var isHovering: Bool { state.hoveredSymbol == item.symbol }
    private var isHighlighted: Bool { state.recentlyAdded == item.symbol }
    private var isDragging: Bool { state.draggingSymbol == item.symbol }

    var body: some View {
        HStack(spacing: 0) {
            Button {
                state.openDetail(item.symbol)
            } label: {
                HStack(spacing: 0) {
                    if isSorting {
                        Image(systemName: "line.3.horizontal")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.tertiary)
                            .frame(width: Self.handleWidth)
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    }
                    WatchRowContent(item: item, quote: quote)
                        .padding(.leading, isSorting ? 0 : Self.contentInset)
                        .padding(.trailing, isSorting ? 0 : Self.contentInset)
                }
                .frame(maxHeight: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .allowsHitTesting(!isSorting)
            .overlay {
                if isSorting {
                    DragHandle(
                        symbol: item.symbol,
                        rowWidth: panelWidth - panelContentInset * 2,
                        preview: { DragPreviewCard(item: item, quote: quote) },
                        onBegin: { state.beginDrag(item.symbol) },
                        onEnd: { state.endDrag() }
                    )
                }
            }

            if isSorting {
                Button(action: onDelete) {
                    Image(systemName: "minus.circle")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .frame(width: Self.deleteWidth)
                        .frame(maxHeight: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointerCursor()
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(RoundedRectangle(cornerRadius: 6).fill(background))
        .opacity(isDragging ? 0.3 : 1)
        .animation(.easeOut(duration: 0.15), value: isDragging)
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

/// What follows the cursor while reordering: the row lifted off the list as a card.
private struct DragPreviewCard: View {
    let item: WatchItem
    let quote: Quote?

    var body: some View {
        WatchRowContent(item: item, quote: quote)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color(nsColor: .windowBackgroundColor))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.primary.opacity(0.1))
            )
    }
}

private struct WatchRowContent: View {
    let item: WatchItem
    let quote: Quote?

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
    }
}
