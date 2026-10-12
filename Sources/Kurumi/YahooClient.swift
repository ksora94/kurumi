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

/// Talks to the same Yahoo Finance endpoints yfinance uses. Chart/search accept plain
/// URLSession requests; quoteSummary needs a cookie + crumb handshake.
struct YahooClient: Sendable {
    static let shared = YahooClient()

    private static let usExchanges: Set<String> = [
        "NMS", "NGM", "NCM", "NAS", "NYQ", "NYS", "ASE", "PCX", "BTS",
    ]
    private static let supportedTypes: Set<String> = ["EQUITY", "ETF"]

    private let session: URLSession
    private let decoder: JSONDecoder
    private let auth: YahooAuth

    init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 10
        // Don't force Accept: application/json globally — getcrumb returns 406 with that header.
        config.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15",
        ]
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        auth = YahooAuth(session: session)
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

    /// Day stats + valuation fields for the detail page (cookie/crumb required).
    func fundamentals(_ symbol: String) async throws -> Fundamentals {
        try await auth.withCrumb { crumb in
            let escaped = symbol.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? symbol
            var components = URLComponents(
                string: "https://query1.finance.yahoo.com/v10/finance/quoteSummary/\(escaped)"
            )!
            components.queryItems = [
                URLQueryItem(name: "modules", value: "price,summaryDetail,defaultKeyStatistics"),
                URLQueryItem(name: "crumb", value: crumb),
            ]
            let response: QuoteSummaryResponse = try await get(components.url!)
            guard let result = response.quoteSummary.result?.first else {
                throw YahooError.noData(symbol)
            }
            return Fundamentals(
                open: result.price?.regularMarketOpen?.raw ?? result.summaryDetail?.open?.raw,
                dayHigh: result.price?.regularMarketDayHigh?.raw ?? result.summaryDetail?.dayHigh?.raw,
                dayLow: result.price?.regularMarketDayLow?.raw ?? result.summaryDetail?.dayLow?.raw,
                previousClose: result.price?.regularMarketPreviousClose?.raw
                    ?? result.summaryDetail?.previousClose?.raw,
                volume: result.price?.regularMarketVolume?.raw ?? result.summaryDetail?.volume?.raw,
                marketCap: result.price?.marketCap?.raw ?? result.summaryDetail?.marketCap?.raw,
                trailingPE: result.summaryDetail?.trailingPE?.raw
                    ?? result.defaultKeyStatistics?.trailingPE?.raw,
                trailingEps: result.defaultKeyStatistics?.trailingEps?.raw
            )
        }
    }

    /// Regular-session price for several symbols in a single request.
    func regularPrices(_ symbols: [String]) async throws -> [String: PriceMove] {
        guard !symbols.isEmpty else { return [:] }
        var components = URLComponents(string: "https://query1.finance.yahoo.com/v7/finance/spark")!
        components.queryItems = [
            URLQueryItem(name: "symbols", value: symbols.joined(separator: ",")),
            URLQueryItem(name: "range", value: "1d"),
            URLQueryItem(name: "interval", value: "1d"),
        ]
        let response: SparkResponse = try await get(components.url!)
        var prices: [String: PriceMove] = [:]
        for item in response.spark.result ?? [] {
            guard let meta = item.response.first?.meta, let price = meta.regularMarketPrice else { continue }
            prices[item.symbol] = PriceMove(price: price, reference: meta.chartPreviousClose ?? price)
        }
        return prices
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
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw YahooError.badStatus(http.statusCode)
        }
        return try decoder.decode(T.self, from: data)
    }
}

/// Maintains Yahoo's cookie jar + crumb for endpoints that require it.
private actor YahooAuth {
    private let session: URLSession
    private var crumb: String?

    init(session: URLSession) {
        self.session = session
    }

    func withCrumb<T: Sendable>(_ body: @Sendable (String) async throws -> T) async throws -> T {
        do {
            let value = try await ensureCrumb()
            return try await body(value)
        } catch YahooError.badStatus(let code) where code == 401 || code == 403 {
            crumb = nil
            let value = try await ensureCrumb()
            return try await body(value)
        }
    }

    private func ensureCrumb() async throws -> String {
        if let crumb { return crumb }
        return try await refreshCrumb()
    }

    private func refreshCrumb() async throws -> String {
        // Seed cookies; status may be 404 but Set-Cookie still lands in the session jar.
        _ = try? await session.data(from: URL(string: "https://fc.yahoo.com")!)
        var request = URLRequest(url: URL(string: "https://query1.finance.yahoo.com/v1/test/getcrumb")!)
        request.setValue("text/plain, */*", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw YahooError.badStatus(http.statusCode)
        }
        guard let crumb = String(data: data, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !crumb.isEmpty,
            !crumb.contains("{"),
            !crumb.contains("Unauthorized")
        else {
            throw YahooError.badStatus(401)
        }
        self.crumb = crumb
        return crumb
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

private struct SparkResponse: Decodable {
    let spark: Spark

    struct Spark: Decodable {
        let result: [Item]?
    }

    struct Item: Decodable {
        let symbol: String
        let response: [Series]
    }

    struct Series: Decodable {
        let meta: Meta
    }

    struct Meta: Decodable {
        let regularMarketPrice: Double?
        let chartPreviousClose: Double?
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

private struct QuoteSummaryResponse: Decodable {
    let quoteSummary: Body

    struct Body: Decodable {
        let result: [Result]?
    }

    struct Result: Decodable {
        let price: PriceModule?
        let summaryDetail: SummaryDetail?
        let defaultKeyStatistics: KeyStatistics?
    }

    struct PriceModule: Decodable {
        let regularMarketOpen: RawValue?
        let regularMarketDayHigh: RawValue?
        let regularMarketDayLow: RawValue?
        let regularMarketPreviousClose: RawValue?
        let regularMarketVolume: RawValue?
        let marketCap: RawValue?
    }

    struct SummaryDetail: Decodable {
        let open: RawValue?
        let dayHigh: RawValue?
        let dayLow: RawValue?
        let previousClose: RawValue?
        let volume: RawValue?
        let marketCap: RawValue?
        let trailingPE: RawValue?
    }

    struct KeyStatistics: Decodable {
        let trailingPE: RawValue?
        let trailingEps: RawValue?
    }

    struct RawValue: Decodable {
        let raw: Double?
    }
}
