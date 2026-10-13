import Charts
import SwiftUI

/// Candles are placed by index rather than time so nights, weekends and holidays leave no gaps.
struct CandleChart: View {
    let candles: [Candle]
    let period: ChartPeriod
    let isLoading: Bool

    /// Room reserved for the trailing price labels when sizing candle bodies.
    private static let yAxisWidth: CGFloat = 40

    var body: some View {
        if candles.count >= 2 {
            chart
        } else {
            ChartPlaceholder(isLoading: isLoading)
        }
    }

    private var chart: some View {
        let lo = candles.map(\.low).min() ?? 0
        let hi = candles.map(\.high).max() ?? 1
        let pad = max((hi - lo) * 0.08, hi * 0.001)
        let minBody = (hi - lo) * 0.003

        return GeometryReader { geometry in
            let slot = (geometry.size.width - Self.yAxisWidth) / CGFloat(candles.count)
            let bodyWidth = max(slot * 0.6, 1)

            Chart(candles) { candle in
                let color = candle.close >= candle.open ? Color.green : Color.red
                let bodyLow = min(candle.open, candle.close)
                let bodyHigh = max(max(candle.open, candle.close), bodyLow + minBody)

                RuleMark(
                    x: .value("序号", Double(candle.id)),
                    yStart: .value("最低", candle.low),
                    yEnd: .value("最高", candle.high)
                )
                .lineStyle(StrokeStyle(lineWidth: 1))
                .foregroundStyle(color)

                RectangleMark(
                    x: .value("序号", Double(candle.id)),
                    yStart: .value("开盘", bodyLow),
                    yEnd: .value("收盘", bodyHigh),
                    width: .fixed(bodyWidth)
                )
                .foregroundStyle(color)
            }
            .chartXScale(domain: -0.5...(Double(candles.count) - 0.5))
            .chartYScale(domain: (lo - pad)...(hi + pad))
            .chartXAxis {
                AxisMarks(values: tickIndices) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.primary.opacity(0.06))
                    AxisValueLabel {
                        if let index = value.as(Double.self), candles.indices.contains(Int(index)) {
                            Text(timeLabel(candles[Int(index)].time))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 3)) { value in
                    AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                        .foregroundStyle(Color.primary.opacity(0.06))
                    AxisValueLabel {
                        if let price = value.as(Double.self) {
                            Text(Format.price(price))
                                .font(.system(size: 9).monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartLegend(.hidden)
        }
    }

    /// Three labels at 1/6, 3/6 and 5/6 of the width, clear of the plot edges.
    private var tickIndices: [Double] {
        [1.0, 3.0, 5.0].map { (Double(candles.count) * $0 / 6).rounded(.down) }
    }

    private func timeLabel(_ date: Date) -> String {
        switch period {
        case .intraday, .fiveMinutes:
            date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute())
        case .oneHour, .oneDay:
            date.formatted(.dateTime.month(.defaultDigits).day())
        case .oneMonth:
            date.formatted(.dateTime.year().month(.defaultDigits))
        }
    }
}
