import SwiftUI

/// A small preview of recent hourly closes. The series is fetched on its own schedule,
/// not with each live quote.
struct Sparkline: View {
    let prices: [Double]
    let color: Color

    var body: some View {
        Canvas { context, size in
            let samples = Self.sampled(prices)
            guard samples.count >= 2, size.width > 0, size.height > 0 else { return }
            let lo = samples.min() ?? 0
            let hi = samples.max() ?? 1
            let span = max(hi - lo, hi * 0.001)
            let inset: CGFloat = 1

            func xPosition(_ index: Int) -> CGFloat {
                let t = CGFloat(index) / CGFloat(samples.count - 1)
                return inset + t * (size.width - inset * 2)
            }
            func yPosition(_ price: Double) -> CGFloat {
                let t = (price - lo) / span
                return inset + (1 - t) * (size.height - inset * 2)
            }

            var line = Path()
            line.move(to: CGPoint(x: xPosition(0), y: yPosition(samples[0])))
            for index in 1..<samples.count {
                line.addLine(to: CGPoint(x: xPosition(index), y: yPosition(samples[index])))
            }

            var fill = line
            fill.addLine(to: CGPoint(x: xPosition(samples.count - 1), y: size.height))
            fill.addLine(to: CGPoint(x: xPosition(0), y: size.height))
            fill.closeSubpath()
            context.fill(
                fill,
                with: .linearGradient(
                    Gradient(colors: [color.opacity(0.28), color.opacity(0.02)]),
                    startPoint: .zero,
                    endPoint: CGPoint(x: 0, y: size.height)
                )
            )
            context.stroke(line, with: .color(color), style: StrokeStyle(lineWidth: 1.25, lineCap: .round, lineJoin: .round))
        }
    }

    /// A 72 pt line doesn't need every bar, so keep the shape and the latest close.
    private static func sampled(_ prices: [Double], limit: Int = 48) -> [Double] {
        guard prices.count > limit, limit > 1 else { return prices }
        let step = Double(prices.count - 1) / Double(limit - 1)
        return (0..<limit).map { index in
            prices[min(Int((Double(index) * step).rounded()), prices.count - 1)]
        }
    }
}
