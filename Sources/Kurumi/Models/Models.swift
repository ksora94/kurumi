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

    var label: String {
        switch self {
        case .pre: "盘前"
        case .regular: "交易中"
        case .post: "盘后"
        case .closed: "休市"
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
