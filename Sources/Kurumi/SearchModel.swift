import Foundation
import Observation

/// View state lives in observable objects instead of `@State`: SwiftUI's property-wrapper
/// macros ship only with Xcode, and this project builds with the Command Line Tools.
@MainActor
@Observable
final class PanelState {
    let search = SearchModel()
    var hoveredSymbol: String?
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
    private(set) var isLoading = false
    private(set) var failed = false
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
            isLoading = false
            failed = false
            return
        }

        isLoading = true
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(250))
            guard !Task.isCancelled else { return }
            do {
                let found = try await YahooClient.shared.search(term)
                guard !Task.isCancelled else { return }
                results = found
                failed = false
            } catch {
                guard !Task.isCancelled else { return }
                results = []
                failed = true
            }
            selection = 0
            isLoading = false
        }
    }
}
