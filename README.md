<p align="center">
  <img src="docs/app-icon.png" width="128" alt="Kurumi">
</p>

<h1 align="center">Kurumi</h1>

<p align="center">Real-time US stock prices in your macOS menu bar.</p>

Kurumi lives quietly in your menu bar: glance up to see the latest prices of your watchlist, or click to open a full quote panel. It's a lightweight native SwiftUI app with no Dock icon, and runs on macOS 14 or later.

## Features

### Menu bar ticker

- Cycles through your watchlist in the menu bar, showing each symbol with its latest price on a red or green tag
- Shows pre-market and after-hours prices outside regular hours, and the live price during the session
- Pauses while you hover so you can read the current one
- Left-click opens the quote panel; right-click opens a menu with Settings and Quit

### Watchlist

- Each stock shows its symbol, company name, a preview of recent hourly prices, the current price and the percent change
- Pre-market and after-hours prices and changes appear below during those sessions
- Sort mode lets you drag to reorder and remove stocks
- Right-click a stock to open it in Yahoo Finance or delete it
- The footer shows the last update time and the market status (pre-market, open, after-hours, closed)
- Your watchlist is saved automatically and restored on relaunch

### Search

- Suggests US stocks and ETFs as you type, across NASDAQ, NYSE, NYSE Arca and other exchanges
- Suggestions include the latest price; pick one with the arrow keys and press Return to add it

### Stock details

- Current price, change and percent change, plus pre-market and after-hours quotes
- Collapsible key metrics: open, high, low, previous close, volume, market cap, P/E and EPS
- Intraday line chart and 5-minute, 1-hour, 1-day and 1-month candlestick charts, remembering your last choice. Moving the pointer over a chart shows that bar's time and the price under the pointer
- One click to open the stock in Yahoo Finance

### Settings

- Language: Simplified Chinese, English or Japanese, following the system by default
- Appearance: light or dark, following the system by default
- Price colors: green for gains and red for losses, or the reverse
- Launch at login
- Menu bar: whether to show prices, price or percent change, and how often to cycle
- Background refresh interval, and whether to show pre-market and after-hours quotes

## Data source

Market data comes from Yahoo Finance's public web endpoints and may be delayed. It's for reference only and is not investment advice.
