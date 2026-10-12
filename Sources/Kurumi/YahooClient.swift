import Foundation

enum YahooError: LocalizedError {
    case badStatus(Int)
    case noData(String)

    var errorDescription: String? {
        switch self {
        case .badStatus(let code): "HTTP \(code)"
        case .noData(let symbol): "\(symbol) 没有数据"
        }
    }
}

/// Talks to the same Yahoo Finance endpoints yfinance uses. Plain URLSession requests are
/// accepted without the cookie/crumb handshake, unlike curl.
struct YahooClient: Sendable {
    static let shared = YahooClient()

    private static let usExchanges: Set<String> = [
        "NMS", "NGM", "NCM", "NAS", "NYQ", "NYS", "ASE", "PCX", "BTS",
    ]
    private static let supportedTypes: Set<String> = ["EQUITY", "ETF"]

    private let session: URLSession
    private let decoder: JSONDecoder

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15",
            "Accept": "application/json",
        ]
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
    }

    func search(_ query: String) async throws -> [SearchResult] {
        var components = URLComponents(string: "https://query2.finance.yahoo.com/v1/finance/search")!
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "quotesCount", value: "15"),
            URLQueryItem(name: "newsCount", value: "0"),
            URLQueryItem(name: "listsCount", value: "0"),
        ]
        let response: SearchResponse = try await get(components.url!)
        return response.quotes.compactMap { item in
            guard let exchange = item.exchange, Self.usExchanges.contains(exchange),
                  let type = item.quoteType, Self.supportedTypes.contains(type)
            else { return nil }
            return SearchResult(
                symbol: item.symbol,
                name: item.longname ?? item.shortname ?? item.symbol,
                exchange: item.exchDisp ?? exchange,
                type: type
            )
        }
    }

    func quote(_ symbol: String) async throws -> Quote {
        let escaped = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
        var components = URLComponents(string: "https://query1.finance.yahoo.com/v8/finance/chart/\(escaped)")!
        components.queryItems = [
            URLQueryItem(name: "interval", value: "1m"),
            URLQueryItem(name: "range", value: "1d"),
            URLQueryItem(name: "includePrePost", value: "true"),
        ]
        let response: ChartResponse = try await get(components.url!)
        guard let result = response.chart.result?.first,
              let price = result.meta.regularMarketPrice
        else { throw YahooError.noData(symbol) }

        let meta = result.meta
        let reference = meta.previousClose ?? meta.chartPreviousClose ?? price
        return Quote(
            symbol: meta.symbol,
            name: meta.longName ?? meta.shortName,
            regular: PriceMove(price: price, reference: reference),
            extended: extendedQuote(result, regularPrice: price),
            periods: meta.currentTradingPeriod
        )
    }

    /// Pre/post-market price is the latest candle printed after the last regular-session trade.
    private func extendedQuote(_ result: ChartResult, regularPrice: Double) -> ExtendedQuote? {
        guard let regularTime = result.meta.regularMarketTime,
              let timestamps = result.timestamp,
              let closes = result.indicators.quote.first?.close
        else { return nil }

        for index in stride(from: min(timestamps.count, closes.count) - 1, through: 0, by: -1) {
            guard let close = closes[index] else { continue }
            let time = timestamps[index]
            guard time > regularTime else { return nil }
            let isPre = result.meta.currentTradingPeriod?.pre.contains(time) ?? false
            return ExtendedQuote(
                session: isPre ? .pre : .post,
                move: PriceMove(price: close, reference: regularPrice)
            )
        }
        return nil
    }

    private func get<T: Decodable>(_ url: URL) async throws -> T {
        let (data, response) = try await session.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw YahooError.badStatus(http.statusCode)
        }
        return try decoder.decode(T.self, from: data)
    }
}

private struct SearchResponse: Decodable {
    let quotes: [Item]

    struct Item: Decodable {
        let symbol: String
        let shortname: String?
        let longname: String?
        let exchange: String?
        let exchDisp: String?
        let quoteType: String?
    }
}

private struct ChartResponse: Decodable {
    let chart: Chart

    struct Chart: Decodable {
        let result: [ChartResult]?
    }
}

private struct ChartResult: Decodable {
    let meta: Meta
    let timestamp: [Date]?
    let indicators: Indicators

    struct Meta: Decodable {
        let symbol: String
        let longName: String?
        let shortName: String?
        let regularMarketPrice: Double?
        let regularMarketTime: Date?
        let previousClose: Double?
        let chartPreviousClose: Double?
        let currentTradingPeriod: TradingPeriods?
    }

    struct Indicators: Decodable {
        let quote: [Series]
    }

    struct Series: Decodable {
        let close: [Double?]?
    }
}
