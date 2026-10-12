import AppKit
import Charts
import SwiftUI

struct DetailView: View {
    let store: WatchlistStore
    let state: PanelState

    private var symbol: String { state.detailSymbol ?? "" }
    private var item: WatchItem? { store.items.first { $0.symbol == symbol } }
    private var quote: Quote? { store.quotes[symbol] }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerBar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    priceBlock
                    section("今日", rows: todayRows)
                    section("概况", rows: overviewRows)
                    if state.fundamentalsFailed && !state.fundamentalsLoading {
                        Text("基本面暂不可用")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    IntradayChart(quote: quote)
                    Button("在 Yahoo Finance 打开") { openYahoo(symbol) }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .pointerCursor()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
            }
            .frame(maxHeight: 520)
        }
        .background(EscapeMonitor { state.closeDetail() })
        .onExitCommand { state.closeDetail() }
    }

    private var headerBar: some View {
        HStack(spacing: 8) {
            Button {
                state.closeDetail()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("返回")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .pointerCursor()

            Spacer(minLength: 8)

            Text(symbol)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private var priceBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(item?.name ?? quote?.name ?? symbol)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let move = quote?.regular {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(Format.price(move.price))
                        .font(.system(size: 22, weight: .semibold).monospacedDigit())
                    Text(Format.change(move))
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundStyle(move.color)
                }
                if let extended = quote?.extended {
                    HStack(spacing: 6) {
                        Text(extended.session.label)
                        Text(Format.price(extended.move.price))
                        Text(Format.percent(extended.move))
                            .foregroundStyle(extended.move.color)
                    }
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            } else {
                Text("—")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var todayRows: [(String, String)] {
        let f = state.fundamentals
        if state.fundamentalsLoading && f == nil {
            return [
                ("开盘", "…"), ("最高", "…"), ("最低", "…"), ("昨收", "…"), ("成交量", "…"),
            ]
        }
        return [
            ("开盘", Format.optionalPrice(f?.open)),
            ("最高", Format.optionalPrice(f?.dayHigh)),
            ("最低", Format.optionalPrice(f?.dayLow)),
            ("昨收", Format.optionalPrice(f?.previousClose ?? quote?.previousClose)),
            ("成交量", Format.volume(f?.volume)),
        ]
    }

    private var overviewRows: [(String, String)] {
        let f = state.fundamentals
        if state.fundamentalsLoading && f == nil {
            return [("市值", "…"), ("市盈率", "…"), ("EPS", "…")]
        }
        return [
            ("市值", Format.marketCap(f?.marketCap)),
            ("市盈率", Format.ratio(f?.trailingPE)),
            ("EPS", Format.eps(f?.trailingEps)),
        ]
    }

    private func section(_ title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            VStack(spacing: 4) {
                ForEach(Array(stride(from: 0, to: rows.count, by: 2)), id: \.self) { index in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        metricCell(rows[index])
                        if index + 1 < rows.count {
                            metricCell(rows[index + 1])
                        } else {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
    }

    private func metricCell(_ row: (String, String)) -> some View {
        HStack(spacing: 4) {
            Text(row.0)
                .foregroundStyle(.secondary)
            Spacer(minLength: 2)
            Text(row.1)
                .font(.system(size: 11).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .font(.system(size: 11))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct IntradayChart: View {
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

/// Popovers often don't put SwiftUI in the key responder chain, so Escape is also watched here.
private struct EscapeMonitor: NSViewRepresentable {
    let onEscape: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak coordinator = context.coordinator] event in
            if event.keyCode == 53 {
                coordinator?.onEscape()
                return nil
            }
            return event
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onEscape = onEscape
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) {
        if let monitor = coordinator.monitor {
            NSEvent.removeMonitor(monitor)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(onEscape: onEscape) }

    final class Coordinator {
        var onEscape: () -> Void
        var monitor: Any?

        init(onEscape: @escaping () -> Void) {
            self.onEscape = onEscape
        }
    }
}
