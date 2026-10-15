# AGENTS.md

Guidance for AI agents working on Kurumi, a macOS menu bar app that shows real-time US stock prices from Yahoo Finance. User-facing features are described in `README.md`; this file covers how to build, verify, and change the code.

## Toolchain constraints

- The machine only has the Command Line Tools (no Xcode). Swift 6.4, macOS 27 SDK, deployment target macOS 14.
- SwiftPM's default build backend doesn't work with CLT; always pass `--build-system native`.
- The SwiftUI macros plugin isn't available, so `@State`, `@Bindable`, `@Entry`, `#Preview` etc. don't compile.
  - Keep view state in `@Observable @MainActor` classes (`PanelState`, `SearchModel`, `AppSettings`, ...) and pass them into views.
  - Build bindings by hand with `Binding(get:set:)` (see the `binding(_:_:)` helper in `SettingsView.swift`).
- `swift build` fails inside the sandbox (`sandbox_apply`); run build commands without the sandbox.

## Build and run

```bash
swift build --build-system native          # debug build, binary at .build/debug/Kurumi
./scripts/build-app.sh                     # release build packaged as build/Kurumi.app
open build/Kurumi.app
```

`build-app.sh` compiles release (falling back to plain `swiftc` if SwiftPM fails to link), renders the app icon from `icon.svg` (or `icon.png`) via `scripts/make-icon.swift`, writes `Info.plist` (`LSUIElement`, bundle id `com.cyan.kurumi`), and ad-hoc signs the bundle.

There are no automated tests. After a change, rebuild the release app and relaunch it (`pkill -x Kurumi; open build/Kurumi.app`) so the user can try it.

## Verifying UI changes

Changes are verified with screenshots of the running debug binary:

1. Add a temporary hook in `AppDelegate.applicationDidFinishLaunching`, gated on an env var, that opens what you need: e.g. show the popover from `statusItem.button`, call `panelState.openDetail("AAPL")`, or `settingsWindow.show(page:)`.
2. Seed data in the debug binary's defaults domain, which is `Kurumi` (the release app uses `com.cyan.kurumi`, so seeding never touches the user's real data):
   ```bash
   HEX=$(printf '%s' '[{"symbol":"AAPL","name":"Apple Inc."},{"symbol":"NVDA","name":"NVIDIA Corporation"}]' | xxd -p | tr -d '\n')
   defaults write Kurumi watchlist -data "$HEX"
   ```
   Other keys can be set the same way (`languagePreference`, `appearance`, `chartPeriod`, ...).
3. `(KURUMI_DEBUG_X=1 nohup .build/debug/Kurumi >/tmp/kurumi.log 2>&1 &); sleep 7; screencapture -x /tmp/shot.png`, then crop with `sips -c <h> <w> --cropOffset <y> <x>` (the screen is 3024×1964 pixels; the popover sits near the top right under the status item).
4. For animation glitches a screenshot can't catch, log geometry over time (e.g. a `GeometryReader` + `NSLog`) and inspect `/tmp/kurumi.log`.
5. Clean up: remove the hook and any logging, `defaults delete Kurumi`, rebuild the release app and relaunch it.

Things that can't be checked this way (drag and drop, hover, right-click menus, launch at login, live setting changes) should be called out for the user to test.

## Architecture

```
Sources/Kurumi/
├── App/        AppDelegate (status item, popover, right-click menu, hidden main menu),
│               MenuBarTicker, SettingsWindowController
├── Models/     Value types (Quote, PriceMove, MarketSession, ChartPeriod, Candle, ...) and formatting
├── Services/   YahooClient (network + decoding), WatchlistStore (persistence + polling)
├── State/      AppSettings, Localization (Loc), PanelState (navigation/sort/drag/detail), SearchModel
├── Views/      Panel/ (shell, header, footer, layout constants), Watchlist/, Search/, Detail/, Settings/
└── Support/    AppKit bridges: DragHandle, EscapeMonitor, OverlayScrollers, PointerCursor, OpenYahoo
```

- **Entry point.** `KurumiMain` runs `NSApplication` with `.accessory` activation (no Dock icon). `AppDelegate` owns the `WatchlistStore`, `PanelState`, `NSStatusItem`, `NSPopover` and settings window.
- **Panel.** An `NSPopover` (`.transient`) hosting `PanelView` through `NSHostingController` with `sizingOptions = [.preferredContentSize]`, so the popover follows the SwiftUI content size. `PanelView` switches between the watchlist, `SearchPage` and `DetailView` based on `PanelState`; navigation resets when the popover closes.
- **Status item clicks.** Left click toggles the popover; right click (or control-click) temporarily assigns `statusMenu` and re-sends the click so the menu appears.
- **Main menu.** Accessory apps never show it, but it must exist so Cmd+Q and the Edit shortcuts (copy/paste/select all in the search field) work.
- **Observation outside SwiftUI.** AppKit code reacts to model changes with re-arming `withObservationTracking` loops (see `MenuBarTicker.observeContent`, `AppDelegate.observeAppearance`).

### Data and refresh

`YahooClient` uses the same unofficial endpoints as yfinance:

| Purpose | Endpoint | Notes |
| --- | --- | --- |
| Quotes + intraday line | `query1 /v8/finance/chart/{symbol}?interval=1m&range=1d&includePrePost=true` | `meta.currentTradingPeriod` provides the pre/regular/post windows |
| Candlesticks | same endpoint with `ChartPeriod.chartQuery` interval/range, `includePrePost=false` | keeps the last 80 bars |
| Search | `query2 /v1/finance/search` | filtered to US exchanges and `EQUITY`/`ETF` |
| Search result prices | `query1 /v7/finance/spark` | one request for all candidates |
| Detail metrics | `query1 /v10/finance/quoteSummary` | needs a cookie (from `fc.yahoo.com`) and crumb (`/v1/test/getcrumb`), handled by `YahooAuth`; retried once on 401/403 |

- **Extended hours.** The pre/post price is the latest 1m candle after `regularMarketTime`, compared against the regular price. `Quote.visibleExtended` hides it when the user turns extended hours off; `Quote.latestMove` (used by the menu bar) is the latest visible price against the previous close.
- **Watchlist sparkline.** Hourly closes from the same `60m` / `3mo` query as the detail chart (last 80 bars). Fetched when the panel opens, then hourly while it stays open, and immediately for a symbol just added. Not part of the quote poll.
- **Polling** (`WatchlistStore.nextPollDelay`): every 5 s while the popover is open during a session (pre/regular/post); `AppSettings.refreshInterval` seconds while it's closed; when the market is closed, sleep until the next known pre-market start, re-checking at least every 30 minutes. Opening the popover restarts polling with an immediate refresh. If every symbol fails (e.g. offline at launch, when the trading schedule is still unknown and the market looks closed), it retries after 5 s, backing off to 60 s, and an `NWPathMonitor` triggers an immediate refresh when the network comes back.
- **Persistence.** The watchlist is JSON in UserDefaults key `watchlist`; the chart period is in `chartPeriod`; settings use the keys in `AppSettings.Keys`.

### Settings

`AppSettings.shared` is an `@Observable @MainActor` singleton; every property writes to UserDefaults in `didSet`, and changes apply instantly (no Save button).

- `upColor`/`downColor` and `PriceMove.color`/`fillColor` read the price color scheme, so anything that shows gains/losses must use them rather than hard-coded `.green`/`.red`.
- `appearance` sets `NSApp.appearance`, plus `popover.appearance` and `statusMenu.appearance` explicitly, because those would otherwise inherit the menu bar's appearance from the status item. The menu bar ticker intentionally keeps following the menu bar.
- Launch at login goes through `SMAppService.mainApp`; `launchesAtLogin` is re-read after every change since registration can fail or need approval.

### Localization

- All user-facing strings live in `Loc` (`State/Localization.swift`) with Chinese, English and Japanese side by side via `pick(zh, en, ja)`. Any new UI text must be added there in all three languages.
- `Language.system` picks the first supported language from `Locale.preferredLanguages`, falling back to English.
- SwiftUI views update automatically because `Loc` reads `AppSettings.shared.language`. AppKit text must be refreshed manually when shown (the status menu titles before each display, the settings window title in `show`).
- Keep English and Japanese labels short; the panel is only 320 pt wide (e.g. the English previous-close label is "Prev").

## UI conventions and pitfalls

- **Layout.** Shared constants are in `Views/Panel/Layout.swift` (`panelWidth` 320, `panelContentInset`, `panelRowSpacing`, `panelBarHeight`); reuse them instead of new magic numbers.
- **Colors.** Use semantic colors (`.primary`, `.secondary`, `Color(nsColor:)`) so light and dark appearances both work.
- **Popover resizing.** `PanelView` pins its content to the top with `.frame(minHeight: 0, maxHeight: .infinity, alignment: .top)`. Without it, SwiftUI centers the content while the popover catches up to a new height and the header visibly jumps. `minHeight: 0` matters; without it, growing content still overflows and jumps.
- **Scrolling.** Only add a `ScrollView` where content can actually overflow (the detail page doesn't). Scrollable lists use `.overlayScrollers()` on their content, which forces thin overlay scrollers that appear on scroll or pointer movement even when a mouse makes macOS use legacy scroll bars.
- **Lists.** The watchlist is a `ScrollView` + `VStack`, not `List`, because `List` adds uncontrollable insets.
- **Popover keyboard.** Popovers often don't put SwiftUI in the key responder chain, so Escape is handled by `EscapeMonitor` (a local event monitor).
- **Drag to reorder.** Implemented with AppKit drag sessions in `DragHandle` plus a SwiftUI `DropDelegate` that reorders live.
- **Menus.** On macOS 27, `NSMenuItem.preferredImageVisibility = .hidden` stops the system from adding icons to menu items. The right-click menu deliberately has only Settings and Quit, with no key equivalents.
- **Menu bar ticker.** The symbol is the status button's title; the colored price tag is an `ImageRenderer` image (`imagePosition = .imageTrailing`). Slides use a `CATransition` push on the button's layer. The item width is fixed to the widest entry so the menu bar doesn't jitter. It falls back to the template app icon when the watchlist is empty or prices are turned off.

## Code style

- Match the surrounding code: small focused views, one type per file where reasonable, `private` helpers.
- Comments explain constraints the code can't show (API quirks, why a workaround exists), not what the next line does. Write comments in English.
- New AppKit bridges go in `Support/`; new persisted preferences go in `AppSettings` with a key in `Keys` and a validated default in `init`.

## Git workflow

- Work on the `develop` branch and push to `origin develop`.
- Use conventional commits (`feat:`, `fix:`, `refactor:`, `docs:`, `chore:`), with a short summary line and a bullet list body.
- Only commit when the user asks.
