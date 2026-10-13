import Charts
import SwiftUI

struct IntradayChart: View {
    let quote: Quote?

    private var points: [IntradayPoint] { quote?.intraday ?? [] }
    private var lineColor: Color { quote?.regular.color ?? .secondary }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("分时")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)

            Group {
                if points.count >= 2 {
                    chart
                } else if quote == nil {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    Text("暂无分时数据")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(height: 130)
        }
    }

    private var chart: some View {
        let prev = quote?.previousClose
        let prices = points.map(\.price) + (prev.map { [$0] } ?? [])
        let lo = (prices.min() ?? 0)
        let hi = (prices.max() ?? 1)
        let pad = max((hi - lo) * 0.08, hi * 0.001)

        return Chart {
            ForEach(points) { point in
                LineMark(
                    x: .value("时间", point.time),
                    y: .value("价格", point.price)
                )
                .interpolationMethod(.linear)
                .foregroundStyle(lineColor)
                .lineStyle(StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
            }

            if let prev {
                RuleMark(y: .value("昨收", prev))
                    .foregroundStyle(Color.secondary.opacity(0.45))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
            }
        }
        .chartYScale(domain: (lo - pad)...(hi + pad))
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5))
                    .foregroundStyle(Color.primary.opacity(0.06))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.hour().minute())
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
