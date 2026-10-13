import SwiftUI

struct EmptyWatchlist: View {
    let onAdd: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.system(size: 22))
                .foregroundStyle(.tertiary)
            Text(Loc.emptyWatchlist)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Button(Loc.addStock, action: onAdd)
                .controlSize(.small)
                .pointerCursor()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }
}
