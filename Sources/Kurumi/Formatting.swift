import SwiftUI

enum Format {
    private static let priceFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        return formatter
    }()

    static func price(_ value: Double) -> String {
        let digits = abs(value) < 1 ? 4 : 2
        priceFormatter.minimumFractionDigits = digits
        priceFormatter.maximumFractionDigits = digits
        return priceFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.2f", value)
    }

    static func change(_ move: PriceMove) -> String {
        let digits = abs(move.price) < 1 ? 4 : 2
        let change = String(format: "%+.\(digits)f", move.change)
        let percent = String(format: "%+.2f%%", move.changePercent)
        return "\(change) (\(percent))"
    }

    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .standard)
    }
}

extension PriceMove {
    /// US convention: green for up, red for down.
    var color: Color {
        if change > 0 { return .green }
        if change < 0 { return .red }
        return .secondary
    }
}
