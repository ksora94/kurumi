import AppKit
import SwiftUI

/// Owns the single settings window; reopening brings the existing one to the front.
@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let navigation = SettingsNavigation()

    func show(page: SettingsPage? = nil) {
        if let page { navigation.page = page }
        if window == nil {
            let hosting = NSHostingController(rootView: SettingsView(navigation: navigation, settings: .shared))
            let window = NSWindow(contentViewController: hosting)
            window.styleMask = [.titled, .closable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.isReleasedWhenClosed = false
            window.setContentSize(hosting.view.fittingSize)
            window.center()
            self.window = window
        }
        window?.title = Loc.settings
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
