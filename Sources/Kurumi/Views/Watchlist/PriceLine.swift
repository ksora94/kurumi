import SwiftUI

/// Price followed by the colored change pill; shared by watchlist rows and search suggestions.
struct PriceLine: View {
    let move: PriceMove

    var body: some View {
        HStack(spacing: 8) {
            Text(Format.price(move.price))
                .font(.system(size: 13, weight: .medium).monospacedDigit())
            ChangePill(move: move)
        }
    }
}

private struct ChangePill: View {
    let move: PriceMove

    var body: some View {
        Text(Format.percent(move))
            .font(.system(size: 11, weight: .semibold).monospacedDigit())
            .foregroundStyle(.white)
            .lineLimit(1)
            // Fixed size keeps prices aligned; wide values like +15.80% shrink their text to fit
            // while the pill itself keeps the same width and height (13pt = one 11pt line).
            .minimumScaleFactor(0.7)
            .frame(width: 46, height: 13)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(RoundedRectangle(cornerRadius: 4).fill(fill))
    }

    private var fill: Color {
        if move.change > 0 { return .green }
        if move.change < 0 { return .red }
        return .gray
    }
}
