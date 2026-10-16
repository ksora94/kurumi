import AppKit
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

    private static let labelFont = NSFont.monospacedDigitSystemFont(ofSize: 10, weight: .medium)
    private static let labelPaddingX: CGFloat = 6
    private static let labelPaddingY: CGFloat = 2

    private var labelText: String {
        "\(period.pointerTime(pointer.time))  \(Format.price(pointer.price))"
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.primary.opacity(0.35))
                .frame(width: 1, height: max(plot.height, 0))
                .position(x: pointer.x, y: plot.midY)
            Text(labelText)
                .font(.system(size: 10, weight: .medium).monospacedDigit())
                .foregroundStyle(.primary)
                .lineLimit(1)
                .padding(.horizontal, Self.labelPaddingX)
                .padding(.vertical, Self.labelPaddingY)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(nsColor: .windowBackgroundColor))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .strokeBorder(Color.primary.opacity(0.12))
                        )
                )
                .fixedSize()
                .position(x: labelX, y: plot.minY + labelHeight / 2)
        }
        .allowsHitTesting(false)
    }

    /// Clamp using the measured label size so the bubble can sit flush against the plot edges.
    private var labelX: CGFloat {
        let half = labelWidth / 2
        let lower = plot.minX + half
        let upper = plot.maxX - half
        guard upper > lower else { return plot.midX }
        return min(max(pointer.x, lower), upper)
    }

    private var labelWidth: CGFloat {
        let size = (labelText as NSString).size(withAttributes: [.font: Self.labelFont])
        return ceil(size.width) + Self.labelPaddingX * 2
    }

    private var labelHeight: CGFloat {
        ceil(Self.labelFont.ascender - Self.labelFont.descender) + Self.labelPaddingY * 2
    }
}
