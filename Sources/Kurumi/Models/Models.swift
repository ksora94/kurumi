import Foundation

struct WatchItem: Codable, Hashable, Identifiable {
    let symbol: String
    var name: String

    var id: String { symbol }
}

struct SearchResult: Hashable, Identifiable {
    let symbol: String
    let name: String
    let exchange: String
    let type: String

    var id: String { symbol }
}

enum MarketSession: Equatable {
    case pre, regular, post, closed

    @MainActor var label: String {
        switch self {
        case .pre: Loc.preMarket
        case .regular: Loc.regularSession
        case .post: Loc.afterHours
        case .closed: Loc.marketClosed
        }
    }

    var isActive: Bool { self != .closed }
}

struct TradingPeriod: Decodable, Equatable {
    let start: Date
    let end: Date

    func contains(_ date: Date) -> Bool { date >= start && date < end }
}

struct TradingPeriods: Decodable, Equatable {
    let pre: TradingPeriod
    let regular: TradingPeriod
    let post: TradingPeriod

    func session(at date: Date) -> MarketSession {
        if pre.contains(date) { return .pre }
        if regular.contains(date) { return .regular }
        if post.contains(date) { return .post }
        return .closed
    }
}

struct PriceMove: Equatable {
    let price: Double
    let change: Double
    let changePercent: Double

    init(price: Double, reference: Double) {
        self.price = price
        change = price - reference
        changePercent = reference == 0 ? 0 : change / reference * 100
    }
}

struct ExtendedQuote: Equatable {
    let session: MarketSession
    let move: PriceMove
}

struct IntradayPoint: Equatable, Identifiable {
    let id: Int
    let time: Date
    let price: Double
}

/// Time scale of the detail chart: the intraday line or one of the candlestick intervals.
enum ChartPeriod: String, CaseIterable, Identifiable {
    case intraday, fiveMinutes, oneHour, oneDay, oneMonth

    /// Candlestick charts show the most recent bars so they stay readable at panel width.
    static let candleCount = 80

    var id: Self { self }

    @MainActor var label: String {
        switch self {
        case .intraday: Loc.periodIntraday
        case .fiveMinutes: Loc.periodFiveMinutes
        case .oneHour: Loc.periodOneHour
        case .oneDay: Loc.periodOneDay
        case .oneMonth: Loc.periodOneMonth
        }
    }

    /// Yahoo chart interval plus a range long enough to cover `candleCount` bars.
    var chartQuery: (interval: String, range: String)? {
        switch self {
        case .intraday: nil
        case .fiveMinutes: ("5m", "5d")
        case .oneHour: ("60m", "3mo")
        case .oneDay: ("1d", "6mo")
        case .oneMonth: ("1mo", "10y")
        }
    }
}

struct Candle: Equatable, Identifiable {
    let id: Int
    let time: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
}

struct Quote: Equatable {
    let symbol: String
    let name: String?
    let regular: PriceMove
    let extended: ExtendedQuote?
    let periods: TradingPeriods?
    /// Yesterday's close used as the day reference (and chart baseline).
    let previousClose: Double?
    /// Intraday 1m closes for the detail chart (includes pre/post when available).
    let intraday: [IntradayPoint]

    /// Pre/post-market quote, unless the user turned extended hours off.
    @MainActor var visibleExtended: ExtendedQuote? {
        AppSettings.shared.showsExtendedHours ? extended : nil
    }

    /// Most recent visible trade, measured against yesterday's close.
    @MainActor var latestMove: PriceMove {
        PriceMove(price: visibleExtended?.move.price ?? regular.price, reference: regular.price - regular.change)
    }
}

/// Snapshot of common day / valuation fields for the detail page.
struct Fundamentals: Equatable {
    var open: Double?
    var dayHigh: Double?
    var dayLow: Double?
    var previousClose: Double?
    var volume: Double?
    var marketCap: Double?
    var trailingPE: Double?
    var trailingEps: Double?
}
