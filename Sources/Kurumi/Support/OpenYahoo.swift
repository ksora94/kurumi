import AppKit

func openYahoo(_ symbol: String) {
    guard let url = URL(string: "https://finance.yahoo.com/quote/\(symbol)") else { return }
    NSWorkspace.shared.open(url)
}
