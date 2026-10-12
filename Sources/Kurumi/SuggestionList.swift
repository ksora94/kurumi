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
                    Text(search.failed ? "搜索失败，请检查网络" : "没有找到匹配的美股")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(search.results.enumerated()), id: \.element.id) { index, result in
                            SuggestionRow(
                                result: result,
                                isSelected: index == search.selection,
                                isAdded: store.contains(result.symbol)
                            )
                            .frame(height: rowHeight)
                            .id(result.id)
                            .onTapGesture { onPick(result) }
                            .onHover { if $0 { search.selection = index } }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .frame(height: min(CGFloat(search.results.count) * rowHeight + 8, 360))
                .onChange(of: search.selection) { _, selection in
                    guard search.results.indices.contains(selection) else { return }
                    proxy.scrollTo(search.results[selection].id)
                }
            }
        }
    }
}

private struct SuggestionRow: View {
    let result: SearchResult
    let isSelected: Bool
    let isAdded: Bool

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(result.symbol)
                    .font(.system(size: 13, weight: .semibold))
                Text(result.name)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 8)
            Text(result.type == "ETF" ? "\(result.exchange) · ETF" : result.exchange)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Image(systemName: isAdded ? "checkmark.circle.fill" : "plus.circle")
                .foregroundStyle(isAdded ? Color.green : Color.secondary)
        }
        .padding(.horizontal, 12)
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor.opacity(0.18) : .clear)
                .padding(.horizontal, 4)
        )
        .contentShape(Rectangle())
    }
}
