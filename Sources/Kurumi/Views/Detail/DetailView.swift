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
                    if state.metricsExpanded {
                        metrics
                            .transition(.opacity)
                    }
                    ChartSection(quote: quote, state: state)
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
            BackButton { state.closeDetail() }
            Spacer(minLength: 8)
            HeaderIconButton(systemName: "arrow.up.right.square") { openYahoo(symbol) }
        }
        .padding(.leading, 12)
        .padding(.trailing, 10)
        .frame(height: panelBarHeight)
    }

    private var priceBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(symbol)
                    .font(.system(size: 13, weight: .semibold))
                Text(item?.name ?? quote?.name ?? "")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer(minLength: 4)
                Button(action: state.toggleMetrics) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .rotationEffect(.degrees(state.metricsExpanded ? 180 : 0))
                        .frame(width: 20, height: 16)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointerCursor()
            }

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

    private static let metricColumns = 3

    /// Each group starts on a new line, three metrics per line.
    private var metricLines: [[(String, String)]] {
        [todayRows, overviewRows].flatMap { rows in
            stride(from: 0, to: rows.count, by: Self.metricColumns).map {
                Array(rows[$0..<min($0 + Self.metricColumns, rows.count)])
            }
        }
    }

    private var metrics: some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(metricLines.enumerated()), id: \.offset) { _, line in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    ForEach(0..<Self.metricColumns, id: \.self) { column in
                        if column < line.count {
                            metricCell(line[column])
                        } else {
                            Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
                        }
                    }
                }
            }
            if state.fundamentalsFailed && !state.fundamentalsLoading {
                Text("基本面暂不可用")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
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
                .foregroundStyle(Color.primary.opacity(0.75))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .font(.system(size: 11))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
