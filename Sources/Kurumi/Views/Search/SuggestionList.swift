import SwiftUI

struct SuggestionList: View {
    let search: SearchModel
    let store: WatchlistStore
    let onPick: (SearchResult) -> Void

    private let rowHeight: CGFloat = 40

    var body: some View {
        if search.results.isEmpty {
            Group {
                if search.isLoading {
                    ProgressView().controlSize(.small)
                } else {
                    Text(Loc.noResults)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: panelRowSpacing) {
                        ForEach(Array(search.results.enumerated()), id: \.element.id) { index, result in
                            SuggestionRow(
                                result: result,
                                price: search.prices[result.symbol],
                                isSelected: index == search.selection,
                                isAdded: store.contains(result.symbol)
                            )
                            .frame(height: rowHeight)
                            .id(result.id)
                            .onTapGesture { onPick(result) }
                            .onHover { if $0 { search.selection = index } }
                        }
                    }
                    .padding(panelContentInset)
                }
                .frame(height: min(listHeight, 360))
                .onChange(of: search.selection) { _, selection in
                    guard search.results.indices.contains(selection) else { return }
                    proxy.scrollTo(search.results[selection].id)
                }
            }
        }
    }

    private var listHeight: CGFloat {
        let count = CGFloat(search.results.count)
        return count * rowHeight + max(count - 1, 0) * panelRowSpacing + panelContentInset * 2
    }
}

private struct SuggestionRow: View {
    let result: SearchResult
    let price: PriceMove?
    let isSelected: Bool
    let isAdded: Bool

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(result.symbol)
                    .font(.system(size: 13, weight: .semibold))
                HStack(spacing: 0) {
                    Text(result.name)
                        .lineLimit(1)
                    Text(" · \(exchange)")
                        .fixedSize()
                }
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            Group {
                if let price {
                    PriceLine(move: price)
                } else {
                    Text("—")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            .fixedSize()
            if isAdded {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Color.green)
            } else {
                Image(systemName: "plus.circle")
                    .foregroundStyle(Color.secondary)
                    .pointerCursor()
            }
        }
        .padding(.horizontal, 10)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : .clear)
        )
        .contentShape(Rectangle())
    }

    /// Kept outside the truncating name so a long company name never hides the exchange.
    private var exchange: String {
        result.type == "ETF" ? "\(result.exchange) · ETF" : result.exchange
    }
}
