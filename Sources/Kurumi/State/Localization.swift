import Foundation

/// Languages the UI is translated into.
enum Language: String {
    case zh, en, ja

    /// First supported language in the user's system preferences, else English.
    static var system: Language {
        for identifier in Locale.preferredLanguages {
            switch Locale(identifier: identifier).language.languageCode?.identifier {
            case "zh": return .zh
            case "ja": return .ja
            case "en": return .en
            default: continue
            }
        }
        return .en
    }
}

/// The language choice shown in settings: follow the system or force one language.
enum LanguagePreference: String, CaseIterable, Identifiable {
    case system, zh, en, ja

    var id: Self { self }

    var resolved: Language {
        switch self {
        case .system: .system
        case .zh: .zh
        case .en: .en
        case .ja: .ja
        }
    }

    /// Explicit languages use their own name so they're recognizable in any UI language.
    @MainActor var label: String {
        switch self {
        case .system: Loc.followSystem
        case .zh: "简体中文"
        case .en: "English"
        case .ja: "日本語"
        }
    }
}

/// UI strings. Reading them goes through `AppSettings`, so SwiftUI views re-render when the
/// language changes; AppKit callers re-read them when their UI is shown.
@MainActor
enum Loc {
    private static func pick(_ zh: String, _ en: String, _ ja: String) -> String {
        switch AppSettings.shared.language {
        case .zh: zh
        case .en: en
        case .ja: ja
        }
    }

    // MARK: Menu

    static var settings: String { pick("设置", "Settings", "設定") }
    static var quit: String { pick("退出", "Quit", "終了") }

    // MARK: Panel

    static var back: String { pick("返回", "Back", "戻る") }
    static var emptyWatchlist: String { pick("还没有自选股票", "No stocks in your watchlist", "ウォッチリストは空です") }
    static var addStock: String { pick("添加股票", "Add Stock", "銘柄を追加") }
    static var openInYahoo: String { pick("在 Yahoo Finance 打开", "Open in Yahoo Finance", "Yahoo Finance で開く") }
    static var delete: String { pick("删除", "Delete", "削除") }
    static func updatedAt(_ time: String) -> String { pick("更新于 \(time)", "Updated \(time)", "\(time) 更新") }
    static var updateFailed: String { pick("更新失败", "Update failed", "更新に失敗しました") }
    static func someUpdatesFailed(_ count: Int) -> String {
        pick("\(count) 只更新失败", "\(count) failed to update", "\(count) 銘柄の更新に失敗")
    }

    // MARK: Search

    static var searchPlaceholder: String { pick("搜索美股代码或公司名", "Search US symbols or companies", "米国株のコードや社名で検索") }
    static var searchHint: String { pick("输入代码或公司名称", "Enter a symbol or company name", "コードまたは社名を入力") }
    static var noResults: String { pick("没有找到相关股票", "No matching stocks", "該当する銘柄がありません") }

    // MARK: Market sessions

    static var preMarket: String { pick("盘前", "Pre-market", "プレ") }
    static var regularSession: String { pick("交易中", "Open", "取引中") }
    static var afterHours: String { pick("盘后", "After-hours", "アフター") }
    static var marketClosed: String { pick("休市", "Closed", "休場") }

    // MARK: Detail

    static var open: String { pick("开盘", "Open", "始値") }
    static var high: String { pick("最高", "High", "高値") }
    static var low: String { pick("最低", "Low", "安値") }
    static var previousClose: String { pick("昨收", "Prev", "前日終値") }
    static var volume: String { pick("成交量", "Volume", "出来高") }
    static var marketCap: String { pick("市值", "Mkt Cap", "時価総額") }
    static var peRatio: String { pick("市盈率", "P/E", "PER") }
    static var eps: String { "EPS" }
    static var fundamentalsUnavailable: String { pick("基本面暂不可用", "Fundamentals unavailable", "指標を取得できません") }
    static var noChartData: String { pick("暂无图表数据", "No chart data", "チャートデータがありません") }

    static var periodIntraday: String { pick("分时", "Intraday", "当日") }
    static var periodFiveMinutes: String { pick("5分钟", "5 min", "5分足") }
    static var periodOneHour: String { pick("1小时", "1 hour", "1時間足") }
    static var periodOneDay: String { pick("1天", "1 day", "日足") }
    static var periodOneMonth: String { pick("1月", "1 month", "月足") }

    // MARK: Settings

    static var general: String { pick("通用", "General", "一般") }
    static var advanced: String { pick("高级", "Advanced", "詳細") }
    static var about: String { pick("关于", "About", "情報") }
    static var language: String { pick("语言", "Language", "言語") }
    static var followSystem: String { pick("跟随系统", "System", "システムに従う") }
    static var appearance: String { pick("外观", "Appearance", "外観") }
    static var lightAppearance: String { pick("浅色", "Light", "ライト") }
    static var darkAppearance: String { pick("深色", "Dark", "ダーク") }
    static var colorScheme: String { pick("涨跌配色", "Price Colors", "騰落の色") }
    static var greenUp: String { pick("绿涨红跌", "Green up, red down", "上昇は緑、下落は赤") }
    static var redUp: String { pick("红涨绿跌", "Red up, green down", "上昇は赤、下落は緑") }
    static var launchAtLogin: String { pick("开机自动启动", "Launch at Login", "ログイン時に起動") }
    static var showMenuBarPrices: String { pick("在菜单栏显示价格", "Show Prices in Menu Bar", "メニューバーに価格を表示") }
    static var menuBarContent: String { pick("显示内容", "Display", "表示内容") }
    static var contentPrice: String { pick("价格", "Price", "価格") }
    static var contentPercent: String { pick("涨跌幅", "Change %", "騰落率") }
    static var scrollInterval: String { pick("滚动间隔", "Scroll Interval", "切り替え間隔") }
    static func seconds(_ count: Int) -> String { pick("\(count) 秒", "\(count) s", "\(count) 秒") }
    static var refreshInterval: String { pick("后台刷新间隔", "Background Refresh", "バックグラウンド更新間隔") }
    static var refreshFootnote: String {
        pick(
            "面板打开时每 5 秒刷新一次；休市期间自动暂停刷新。",
            "Refreshes every 5 seconds while the panel is open, and pauses while the market is closed.",
            "パネル表示中は 5 秒ごとに更新し、休場中は更新を停止します。"
        )
    }
    static var showExtendedHours: String { pick("显示盘前盘后价格", "Show Pre-market & After-hours", "時間外の価格を表示") }
    static var extendedHoursFootnote: String {
        pick(
            "关闭后列表和详情页不再显示盘前盘后行情，菜单栏显示常规交易时段价格。",
            "When off, the list and detail page hide extended-hours quotes and the menu bar shows the regular-session price.",
            "オフにすると、リストと詳細画面に時間外の価格を表示せず、メニューバーには通常取引の価格を表示します。"
        )
    }
    static var developmentBuild: String { pick("开发版", "Development", "開発版") }
    static func version(_ value: String) -> String { pick("版本 \(value)", "Version \(value)", "バージョン \(value)") }
    static var viewOnGitHub: String { pick("在 GitHub 上查看", "View on GitHub", "GitHub で見る") }
    static var disclaimer: String {
        pick(
            "行情数据来自 Yahoo Finance 公开接口，可能存在延迟，仅供参考，不构成任何投资建议。",
            "Market data comes from Yahoo Finance's public endpoints and may be delayed. For reference only; not investment advice.",
            "相場データは Yahoo Finance の公開 API から取得しており、遅延する場合があります。参考情報であり、投資助言ではありません。"
        )
    }
}
