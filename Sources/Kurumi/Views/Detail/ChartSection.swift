import SwiftUI

/// Period tabs above the detail chart; intraday draws a line, the rest draw candles.
struct ChartSection: View {
    let quote: Quote?
    let state: PanelState

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 2) {
                ForEach(ChartPeriod.allCases) { period in
                    PeriodTab(
                        label: period.label,
                        isSelected: period == state.chartPeriod,
                        action: { state.selectChartPeriod(period) }
                    )
                }
            }

            Group {
                if state.chartPeriod == .intraday {
                    IntradayChart(quote: quote)
                } else {
                    CandleChart(candles: state.candles, period: state.chartPeriod, isLoading: state.candlesLoading)
                }
            }
            .frame(height: 200)
        }
    }
}

private struct PeriodTab: View {
    let label: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? Color.primary : Color.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .fill(isSelected ? Color.primary.opacity(0.08) : .clear)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .pointerCursor()
    }
}

struct ChartPlaceholder: View {
    let isLoading: Bool

    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text(Loc.noChartData)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
