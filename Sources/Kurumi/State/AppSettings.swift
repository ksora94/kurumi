import Foundation
import Observation
import ServiceManagement
import SwiftUI

enum PriceColorScheme: String, CaseIterable, Identifiable {
    case greenUp, redUp

    var id: Self { self }

    var label: String {
        switch self {
        case .greenUp: "绿涨红跌"
        case .redUp: "红涨绿跌"
        }
    }
}

enum MenuBarContent: String, CaseIterable, Identifiable {
    case price, percent

    var id: Self { self }

    var label: String {
        switch self {
        case .price: "价格"
        case .percent: "涨跌幅"
        }
    }
}

/// User preferences, persisted to UserDefaults as soon as they change.
@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    static let scrollIntervalOptions = [3, 5, 10, 30]
    static let refreshIntervalOptions = [10, 20, 30, 60]

    var colorScheme: PriceColorScheme {
        didSet { defaults.set(colorScheme.rawValue, forKey: Keys.colorScheme) }
    }

    var showsMenuBarPrices: Bool {
        didSet { defaults.set(showsMenuBarPrices, forKey: Keys.showsMenuBarPrices) }
    }

    var menuBarContent: MenuBarContent {
        didSet { defaults.set(menuBarContent.rawValue, forKey: Keys.menuBarContent) }
    }

    /// Seconds between menu bar ticker slides.
    var scrollInterval: Int {
        didSet { defaults.set(scrollInterval, forKey: Keys.scrollInterval) }
    }

    /// Seconds between refreshes during a session while the panel is closed.
    var refreshInterval: Int {
        didSet { defaults.set(refreshInterval, forKey: Keys.refreshInterval) }
    }

    var showsExtendedHours: Bool {
        didSet { defaults.set(showsExtendedHours, forKey: Keys.showsExtendedHours) }
    }

    /// Mirrors the system login item; re-read after every change since registration can fail
    /// or need approval in System Settings.
    private(set) var launchesAtLogin = SMAppService.mainApp.status == .enabled

    @ObservationIgnored private let defaults = UserDefaults.standard

    private enum Keys {
        static let colorScheme = "colorScheme"
        static let showsMenuBarPrices = "showsMenuBarPrices"
        static let menuBarContent = "menuBarContent"
        static let scrollInterval = "scrollInterval"
        static let refreshInterval = "refreshInterval"
        static let showsExtendedHours = "showsExtendedHours"
    }

    private init() {
        let defaults = UserDefaults.standard
        colorScheme = PriceColorScheme(rawValue: defaults.string(forKey: Keys.colorScheme) ?? "") ?? .greenUp
        showsMenuBarPrices = defaults.object(forKey: Keys.showsMenuBarPrices) as? Bool ?? true
        menuBarContent = MenuBarContent(rawValue: defaults.string(forKey: Keys.menuBarContent) ?? "") ?? .price
        scrollInterval = Self.validated(defaults.integer(forKey: Keys.scrollInterval), in: Self.scrollIntervalOptions, default: 5)
        refreshInterval = Self.validated(defaults.integer(forKey: Keys.refreshInterval), in: Self.refreshIntervalOptions, default: 20)
        showsExtendedHours = defaults.object(forKey: Keys.showsExtendedHours) as? Bool ?? true
    }

    func setLaunchesAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Kurumi: failed to update login item: \(error)")
        }
        launchesAtLogin = SMAppService.mainApp.status == .enabled
    }

    var upColor: Color { colorScheme == .greenUp ? .green : .red }
    var downColor: Color { colorScheme == .greenUp ? .red : .green }

    private static func validated(_ value: Int, in options: [Int], default fallback: Int) -> Int {
        options.contains(value) ? value : fallback
    }
}
