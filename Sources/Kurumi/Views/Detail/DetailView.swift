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
            BackButton { state.closeDetail() }

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
