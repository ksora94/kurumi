import AppKit
import Observation
import SwiftUI

@main
@MainActor
enum KurumiMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private let store = WatchlistStore()
    private let panelState = PanelState()
    private let popover = NSPopover()
    private var statusItem: NSStatusItem!
    private var ticker: MenuBarTicker?
    private let settingsWindow = SettingsWindowController()

    private lazy var statusMenu: NSMenu = {
        let menu = NSMenu()
        menu.addItem(plainMenuItem(Loc.settings, action: #selector(openSettings)))
        menu.addItem(plainMenuItem(Loc.quit, action: #selector(quit)))
        return menu
    }()

    /// Re-read before each display so the menu follows the current language.
    private func refreshMenuTitles() {
        statusMenu.items[0].title = Loc.settings
        statusMenu.items[1].title = Loc.quit
    }

    /// No key equivalent and no system-supplied icon.
    private func plainMenuItem(_ title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        if #available(macOS 27.0, *) {
            item.preferredImageVisibility = .hidden
        }
        return item
    }

    @objc private func openSettings() {
        popover.performClose(nil)
        settingsWindow.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = makeMainMenu()

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        let icon = Self.statusImage()
        if let button = statusItem.button {
            button.image = icon
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        ticker = MenuBarTicker(statusItem: statusItem, store: store, icon: icon)

        let hosting = NSHostingController(rootView: PanelView(store: store, state: panelState))
        hosting.sizingOptions = [.preferredContentSize]
        popover.contentViewController = hosting
        popover.behavior = .transient
        popover.delegate = self

        observeAppearance()
        store.start()
        ticker?.start()
    }

    /// The status item itself stays with the menu bar; only the app's own windows and menus
    /// take the chosen appearance. The popover and menu are set directly because they would
    /// otherwise inherit the menu bar's appearance from the status item.
    private func observeAppearance() {
        let appearance = withObservationTracking {
            AppSettings.shared.appearance.nsAppearance
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeAppearance() }
        }
        NSApp.appearance = appearance
        popover.appearance = appearance
        statusMenu.appearance = appearance
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            popover.performClose(nil)
            refreshMenuTitles()
            statusItem.menu = statusMenu
            sender.performClick(nil)
            statusItem.menu = nil
        } else if popover.isShown {
            popover.performClose(nil)
        } else {
            NSApp.activate(ignoringOtherApps: true)
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
        }
    }

    func popoverDidShow(_ notification: Notification) {
        store.isPanelVisible = true
    }

    func popoverDidClose(_ notification: Notification) {
        store.isPanelVisible = false
        panelState.resetPanelNavigation()
    }

    private static func statusImage() -> NSImage {
        let image = Bundle.main.image(forResource: "icon")
            ?? NSImage(systemSymbolName: "chart.line.uptrend.xyaxis", accessibilityDescription: "Kurumi")!
        image.size = NSSize(width: 18, height: 18)
        image.isTemplate = true
        return image
    }

    /// Accessory apps have no visible menu bar, but key equivalents (Cmd+Q, Cmd+C/V/A in the
    /// search field) still route through the main menu.
    private func makeMainMenu() -> NSMenu {
        let mainMenu = NSMenu()

        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "退出 Kurumi", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let appItem = NSMenuItem()
        appItem.submenu = appMenu
        mainMenu.addItem(appItem)

        let editMenu = NSMenu(title: "编辑")
        editMenu.addItem(withTitle: "撤销", action: Selector(("undo:")), keyEquivalent: "z")
        let redo = editMenu.addItem(withTitle: "重做", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "剪切", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "拷贝", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "粘贴", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        editMenu.addItem(withTitle: "全选", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        let editItem = NSMenuItem()
        editItem.submenu = editMenu
        mainMenu.addItem(editItem)

        return mainMenu
    }
}
