import Foundation
import Observation
import SwiftUI

/// The detail chart's hover readout: the nearest bar's time, the price under the pointer,
/// and the bar's x position in the chart view.
struct ChartPointer: Equatable {
    var time: Date
    var price: Double
    var x: CGFloat
}

/// View state lives in observable objects instead of `@State`: SwiftUI's property-wrapper
/// macros ship only with Xcode, and this project builds with the Command Line Tools.
@MainActor
@Observable
final class PanelState {
    let search = SearchModel()
    var hoveredSymbol: String?
    /// Sort mode shows drag handles and delete buttons on every row; rows don't open details.
    private(set) var isSorting = false
    private(set) var draggingSymbol: String?
    private(set) var recentlyAdded: String?

    /// When set, the panel shows the detail page for this symbol instead of the list.
    private(set) var detailSymbol: String?
    private(set) var fundamentals: Fundamentals?
    private(set) var fundamentalsLoading = false
    private(set) var fundamentalsFailed = false
    /// Whether the detail page's metric grid is expanded; collapsed each time a detail opens.
    private(set) var metricsExpanded = false

    /// Remembered across stocks and launches.
    private(set) var chartPeriod = ChartPeriod(
        rawValue: UserDefaults.standard.string(forKey: PanelState.chartPeriodKey) ?? ""
    ) ?? .intraday
    private(set) var candles: [Candle] = []
    private(set) var candlesLoading = false
    /// Set while the pointer is over the detail chart.
    var chartPointer: ChartPointer?

    @ObservationIgnored private var fundamentalsTask: Task<Void, Never>?
    @ObservationIgnored private var candlesTask: Task<Void, Never>?

    private static let chartPeriodKey = "chartPeriod"

    var isShowingDetail: Bool { detailSymbol != nil }

    /// The search page replaces the list; the search field only exists there.
    private(set) var isSearching = false

    func openSearch() {
        hoveredSymbol = nil
        isSearching = true
    }

    func toggleSorting() {
        withAnimation(.easeOut(duration: 0.15)) { isSorting.toggle() }
    }

    func endSorting() {
        guard isSorting else { return }
        withAnimation(.easeOut(duration: 0.15)) { isSorting = false }
    }

    func closeSearch() {
        search.clear()
        isSearching = false
    }

    func beginDrag(_ symbol: String) {
        draggingSymbol = symbol
    }

    func endDrag() {
        guard draggingSymbol != nil else { return }
        withAnimation(.easeOut(duration: 0.15)) { draggingSymbol = nil }
    }

    func markAdded(_ symbol: String) {
        recentlyAdded = symbol
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            guard recentlyAdded == symbol else { return }
            withAnimation(.easeOut(duration: 0.4)) { recentlyAdded = nil }
        }
    }

    func openDetail(_ symbol: String) {
        detailSymbol = symbol
        hoveredSymbol = nil
        metricsExpanded = false
        chartPointer = nil
        loadFundamentals(for: symbol)
        loadCandles(for: symbol)
    }

    func toggleMetrics() {
        withAnimation(.easeOut(duration: 0.2)) { metricsExpanded.toggle() }
    }

    func selectChartPeriod(_ period: ChartPeriod) {
        guard period != chartPeriod else { return }
        chartPointer = nil
        chartPeriod = period
        UserDefaults.standard.set(period.rawValue, forKey: Self.chartPeriodKey)
        if let detailSymbol { loadCandles(for: detailSymbol) }
    }

    func closeDetail() {
        fundamentalsTask?.cancel()
        fundamentalsTask = nil
        candlesTask?.cancel()
        candlesTask = nil
        candles = []
        candlesLoading = false
        chartPointer = nil
        detailSymbol = nil
        fundamentals = nil
        fundamentalsLoading = false
        fundamentalsFailed = false
    }

    /// Reset navigation when the popover closes so the next open lands on the watchlist.
    func resetPanelNavigation() {
        closeSearch()
        closeDetail()
        hoveredSymbol = nil
        isSorting = false
        endDrag()
    }

    private func loadFundamentals(for symbol: String) {
        fundamentalsTask?.cancel()
        fundamentals = nil
        fundamentalsFailed = false
        fundamentalsLoading = true
        fundamentalsTask = Task {
            let fetched = try? await YahooClient.shared.fundamentals(symbol)
            guard !Task.isCancelled, detailSymbol == symbol else { return }
            fundamentals = fetched
            fundamentalsFailed = fetched == nil
            fundamentalsLoading = false
        }
    }

    private func loadCandles(for symbol: String) {
        candlesTask?.cancel()
        candles = []
        guard chartPeriod != .intraday else {
            candlesLoading = false
            return
        }
        candlesLoading = true
        let period = chartPeriod
        candlesTask = Task {
            let fetched = try? await YahooClient.shared.candles(symbol, period: period)
            guard !Task.isCancelled, detailSymbol == symbol, chartPeriod == period else { return }
            candles = fetched ?? []
            candlesLoading = false
        }
    }
}
