import Foundation
import Observation
import SwiftUI

/// View state lives in observable objects instead of `@State`: SwiftUI's property-wrapper
/// macros ship only with Xcode, and this project builds with the Command Line Tools.
@MainActor
@Observable
final class PanelState {
    let search = SearchModel()
    var hoveredSymbol: String?
    var draggingSymbol: String?
    private(set) var recentlyAdded: String?

    /// When set, the panel shows the detail page for this symbol instead of the list.
    private(set) var detailSymbol: String?
    private(set) var fundamentals: Fundamentals?
    private(set) var fundamentalsLoading = false
    private(set) var fundamentalsFailed = false

    @ObservationIgnored private var fundamentalsTask: Task<Void, Never>?

    var isShowingDetail: Bool { detailSymbol != nil }

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
        loadFundamentals(for: symbol)
    }

    func closeDetail() {
        fundamentalsTask?.cancel()
        fundamentalsTask = nil
        detailSymbol = nil
        fundamentals = nil
        fundamentalsLoading = false
        fundamentalsFailed = false
    }

    /// Reset navigation when the popover closes so the next open lands on the watchlist.
    func resetPanelNavigation() {
        search.clear()
        closeDetail()
        hoveredSymbol = nil
        draggingSymbol = nil
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
}

@MainActor
@Observable
final class SearchModel {
    var query = "" {
        didSet {
            guard query != oldValue else { return }
            scheduleSearch()
        }
    }

    private(set) var results: [SearchResult] = []
    private(set) var prices: [String: PriceMove] = [:]
    private(set) var isLoading = false
    var selection = 0

    @ObservationIgnored private var searchTask: Task<Void, Never>?

    var trimmedQuery: String { query.trimmingCharacters(in: .whitespacesAndNewlines) }
    var isActive: Bool { !trimmedQuery.isEmpty }

    var selected: SearchResult? {
        results.indices.contains(selection) ? results[selection] : nil
    }

    func moveSelection(by delta: Int) {
        guard !results.isEmpty else { return }
        selection = min(max(selection + delta, 0), results.count - 1)
    }

    func clear() {
        query = ""
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let term = trimmedQuery
        guard !term.isEmpty else {
            results = []
            prices = [:]
            isLoading = false
            return
        }

        isLoading = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            let found = (try? await YahooClient.shared.search(term)) ?? []
            guard !Task.isCancelled else { return }
            results = found
            prices = [:]
            selection = 0
            isLoading = false

            // Prices are optional decoration: on failure the rows simply keep their placeholders.
            let fetched = (try? await YahooClient.shared.regularPrices(found.map(\.symbol))) ?? [:]
            guard !Task.isCancelled else { return }
            prices = fetched
        }
    }
}
