import SwiftUI

struct EmptyWatchlist: View {
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
