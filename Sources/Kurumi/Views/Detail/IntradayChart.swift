import Charts
import SwiftUI

struct IntradayChart: View {
    let quote: Quote?
    let state: PanelState

    private var points: [IntradayPoint] { quote?.intraday ?? [] }
    private var lineColor: Color { quote?.regular.color ?? .secondary }

    var body: some View {
        if points.count >= 2 {
            chart
        } else if quote == nil {
            ChartPlaceholder(isLoading: true)
        } else {
            ChartPlaceholder(isLoading: false)
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
        .chartOverlay { proxy in
            ChartHoverSurface(state: state, period: .intraday, proxy: proxy) { location, plot, proxy in
                Self.pointer(at: location, plot: plot, proxy: proxy, points: points)
            }
        }
        .cursor(.crosshair)
    }

    /// Snaps the guide to the nearest minute; the price is wherever the pointer sits vertically.
    private static func pointer(at location: CGPoint, plot: CGRect, proxy: ChartProxy, points: [IntradayPoint]) -> ChartPointer? {
        guard plot.contains(location), let nearest = nearest(toX: location.x - plot.minX, proxy: proxy, points: points) else {
            return nil
        }
        guard let price = proxy.value(atY: location.y - plot.minY, as: Double.self), price.isFinite,
              let x = proxy.position(forX: nearest.time)
        else { return nil }
        return ChartPointer(time: nearest.time, price: price, x: x)
    }

    private static func nearest(toX x: CGFloat, proxy: ChartProxy, points: [IntradayPoint]) -> IntradayPoint? {
        guard let date = proxy.value(atX: x, as: Date.self), let first = points.first else { return nil }
        if date <= first.time { return first }
        guard let last = points.last else { return nil }
        if date >= last.time { return last }
        var low = 0
        var high = points.count - 1
        while low < high {
            let mid = (low + high) / 2
            if points[mid].time < date { low = mid + 1 } else { high = mid }
        }
        let previous = points[max(low - 1, 0)]
        return abs(previous.time.timeIntervalSince(date)) <= abs(points[low].time.timeIntervalSince(date))
            ? previous : points[low]
    }
}
