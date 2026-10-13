import Foundation
import Observation

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
