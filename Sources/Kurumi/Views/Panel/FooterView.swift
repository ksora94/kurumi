import SwiftUI

struct FooterView: View {
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
