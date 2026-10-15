import Charts
import SwiftUI

/// Tracks the pointer over a detail chart and draws a vertical guide on the nearest bar.
struct ChartHoverSurface: View {
    let state: PanelState
    let period: ChartPeriod
    let proxy: ChartProxy
    let locate: (CGPoint, CGRect, ChartProxy) -> ChartPointer?

    var body: some View {
        GeometryReader { geometry in
            let plot = proxy.plotFrame.map { geometry[$0] } ?? .zero
            ZStack {
                Color.clear
                    .contentShape(Rectangle())
                    .onContinuousHover { phase in
                        switch phase {
                        case .active(let location):
                            state.chartPointer = locate(location, plot, proxy)
                        case .ended:
                            state.chartPointer = nil
                        }
                    }
                if let pointer = state.chartPointer {
                    ChartPointerGuide(pointer: pointer, period: period, plot: plot)
                }
            }
        }
    }
}

/// Vertical guide with the snapped bar's time and the price at the pointer's height.
private struct ChartPointerGuide: View {
    let pointer: ChartPointer
    let period: ChartPeriod
    let plot: CGRect

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.primary.opacity(0.35))
                .frame(width: 1, height: max(plot.height, 0))
                .position(x: pointer.x, y: plot.midY)
            Text("\(period.pointerTime(pointer.time))  \(Format.price(pointer.price))")
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Color.primary.opacity(0.12))
                        )
                )
                .fixedSize()
                .position(x: labelX, y: plot.minY + 11)
        }
        .allowsHitTesting(false)
    }

    /// Keeps the label inside the plot. 64 pt covers about half of the longest readout.
    private var labelX: CGFloat {
        let half: CGFloat = 64
        let lower = plot.minX + half
        let upper = plot.maxX - half
        guard upper > lower else { return plot.midX }
        return min(max(pointer.x, lower), upper)
    }
}
