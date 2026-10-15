import Foundation
import Network
import Observation

@MainActor
@Observable
final class WatchlistStore {
    private(set) var items: [WatchItem] = []
    private(set) var quotes: [String: Quote] = [:]
    private(set) var periods: TradingPeriods?
    private(set) var lastUpdated: Date?
    /// How many symbols failed in the last refresh, and out of how many.
    private(set) var lastFailure: (failed: Int, total: Int)?
    /// Recent hourly closes for the watchlist preview, refreshed separately from live quotes.
    private(set) var hourlyCloses: [String: [Double]] = [:]

    var isPanelVisible = false {
        didSet {
            guard isPanelVisible != oldValue else { return }
            restartPolling(refreshFirst: isPanelVisible)
            restartHourly()
        }
    }

    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var hourlyTask: Task<Void, Never>?
    @ObservationIgnored private var hourlyFetchedAt: [String: Date] = [:]
    @ObservationIgnored private let client = YahooClient.shared
    /// Refreshes in a row where every symbol failed, e.g. while offline.
    @ObservationIgnored private var consecutiveFailures = 0
    @ObservationIgnored private let pathMonitor = NWPathMonitor()
    @ObservationIgnored private var isOnline = true
    private static let defaultsKey = "watchlist"
    private static let hourlyInterval: TimeInterval = 60 * 60

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.defaultsKey),
           let saved = try? JSONDecoder().decode([WatchItem].self, from: data) {
            items = saved
        }
    }

    func start() {
        restartPolling(refreshFirst: true)
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let online = path.status == .satisfied
            Task { @MainActor in self?.networkChanged(online: online) }
        }
        pathMonitor.start(queue: .main)
    }

    /// Refreshes right away when the network comes back, if the last quote refresh failed
    /// or an hourly preview is still missing.
    private func networkChanged(online: Bool) {
        defer { isOnline = online }
        guard online, !isOnline else { return }
        if consecutiveFailures > 0 { restartPolling(refreshFirst: true) }
        if isPanelVisible, !symbolsDueForHourly().isEmpty { restartHourly() }
    }

    func session(at date: Date = .now) -> MarketSession {
        periods?.session(at: date) ?? .closed
    }

    func contains(_ symbol: String) -> Bool {
        items.contains { $0.symbol == symbol }
    }

    func add(_ result: SearchResult) {
        guard !contains(result.symbol) else { return }
        items.append(WatchItem(symbol: result.symbol, name: result.name))
        save()
        Task { await refresh(symbols: [result.symbol]) }
        Task { await refreshHourly(symbols: [result.symbol]) }
    }

    func remove(_ symbol: String) {
        items.removeAll { $0.symbol == symbol }
        quotes[symbol] = nil
        hourlyCloses[symbol] = nil
        hourlyFetchedAt[symbol] = nil
        save()
    }

    func move(from source: IndexSet, to destination: Int) {
        items.move(fromOffsets: source, toOffset: destination)
        save()
    }

    func refresh(symbols: [String]? = nil) async {
        let symbols = symbols ?? items.map(\.symbol)
        guard !symbols.isEmpty else { return }

        let client = client
        let results = await withTaskGroup(of: (String, Quote?).self) { group in
            for symbol in symbols {
                group.addTask { (symbol, try? await client.quote(symbol)) }
            }
            var collected: [(String, Quote?)] = []
            for await result in group { collected.append(result) }
            return collected
        }
        guard !Task.isCancelled else { return }

        var failures = 0
        for (symbol, quote) in results {
            guard let quote else {
                failures += 1
                continue
            }
            guard contains(symbol) else { continue }
            quotes[symbol] = quote
            if let periods = quote.periods { self.periods = periods }
        }

        consecutiveFailures = failures == results.count ? consecutiveFailures + 1 : 0
        if failures < results.count { lastUpdated = .now }
        lastFailure = failures == 0 ? nil : (failures, results.count)
    }

    /// Loads hourly closes when the panel opens, then refreshes them hourly while it stays open.
    /// Quotes keep their own, much faster poll.
    private func restartHourly() {
        hourlyTask?.cancel()
        guard isPanelVisible else { return }
        hourlyTask = Task { [weak self] in
            guard let self else { return }
            await self.refreshHourly(symbols: self.symbolsDueForHourly())
            if !Task.isCancelled, !self.symbolsDueForHourly().isEmpty {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled else { return }
                await self.refreshHourly(symbols: self.symbolsDueForHourly())
            }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Self.hourlyInterval))
                guard !Task.isCancelled, self.isPanelVisible else { return }
                await self.refreshHourly(symbols: self.items.map(\.symbol))
            }
        }
    }

    private func symbolsDueForHourly() -> [String] {
        let now = Date.now
        return items.map(\.symbol).filter { symbol in
            guard let fetched = hourlyFetchedAt[symbol] else { return true }
            return now.timeIntervalSince(fetched) >= Self.hourlyInterval
        }
    }

    private func refreshHourly(symbols: [String]) async {
        guard !symbols.isEmpty else { return }
        let client = client
        let results = await withTaskGroup(of: (String, [Double]?).self) { group in
            for symbol in symbols {
                group.addTask {
                    let candles = try? await client.candles(symbol, period: .oneHour)
                    return (symbol, candles?.map(\.close))
                }
            }
            var collected: [(String, [Double]?)] = []
            for await result in group { collected.append(result) }
            return collected
        }
        guard !Task.isCancelled else { return }

        let now = Date.now
        for (symbol, closes) in results {
            guard contains(symbol), let closes, closes.count >= 2 else { continue }
            hourlyCloses[symbol] = closes
            hourlyFetchedAt[symbol] = now
        }
    }

    private func restartPolling(refreshFirst: Bool) {
        pollTask?.cancel()
        pollTask = Task { [weak self] in
            var shouldRefresh = refreshFirst
            while !Task.isCancelled {
                guard let self else { return }
                if shouldRefresh { await self.refresh() }
                shouldRefresh = true
                try? await Task.sleep(for: .seconds(self.nextPollDelay()))
            }
        }
    }

    /// Polls fast while a session (pre/regular/post) is open, otherwise sleeps until the next
    /// known pre-market open, re-checking at least every 30 minutes in case the schedule changed.
    /// After a refresh where everything failed, retries soon (backing off to a minute) instead,
    /// since without data the trading schedule is unknown and the market looks closed.
    private func nextPollDelay() -> TimeInterval {
        if consecutiveFailures > 0 {
            return min(5 * pow(2, Double(consecutiveFailures - 1)), 60)
        }
        let now = Date.now
        if session(at: now).isActive {
            return isPanelVisible ? 5 : TimeInterval(AppSettings.shared.refreshInterval)
        }
        let idle: TimeInterval = 30 * 60
        if let start = periods?.pre.start, start > now {
            return min(start.timeIntervalSince(now) + 1, idle)
        }
        return idle
    }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }
}
