import AppKit
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
                VStack(alignment: .leading, spacing: 14) {
                    priceBlock
                    section("今日", rows: todayRows)
                    section("概况", rows: overviewRows)
                    if state.fundamentalsFailed && !state.fundamentalsLoading {
                        Text("基本面暂不可用")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Button("在 Yahoo Finance 打开") { openYahoo(symbol) }
                        .buttonStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .pointerCursor()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }
            .frame(maxHeight: 440)
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
        .padding(.vertical, 9)
    }

    private var priceBlock: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item?.name ?? quote?.name ?? symbol)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            if let move = quote?.regular {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(Format.price(move.price))
                        .font(.system(size: 26, weight: .semibold).monospacedDigit())
                    VStack(alignment: .leading, spacing: 2) {
                        Text(Format.change(move))
                            .font(.system(size: 12, weight: .medium).monospacedDigit())
                            .foregroundStyle(move.color)
                    }
                }
                if let extended = quote?.extended {
                    HStack(spacing: 6) {
                        Text(extended.session.label)
                        Text(Format.price(extended.move.price))
                        Text(Format.percent(extended.move))
                            .foregroundStyle(extended.move.color)
                    }
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundStyle(.secondary)
                }
            } else {
                Text("—")
                    .font(.system(size: 26, weight: .semibold))
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
            ("昨收", Format.optionalPrice(f?.previousClose)),
            ("成交量", Format.volume(f?.volume)),
        ]
    }

    private var overviewRows: [(String, String)] {
        let f = state.fundamentals
        if state.fundamentalsLoading && f == nil {
            return [("市值", "…"), ("市盈率 (TTM)", "…"), ("EPS (TTM)", "…")]
        }
        return [
            ("市值", Format.marketCap(f?.marketCap)),
            ("市盈率 (TTM)", Format.ratio(f?.trailingPE)),
            ("EPS (TTM)", Format.eps(f?.trailingEps)),
        ]
    }

    private func section(_ title: String, rows: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
            VStack(spacing: 5) {
                ForEach(rows, id: \.0) { row in
                    HStack {
                        Text(row.0)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 8)
                        Text(row.1)
                            .font(.system(size: 12).monospacedDigit())
                    }
                    .font(.system(size: 12))
                }
            }
        }
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
