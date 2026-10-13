import AppKit
import Observation
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case general, advanced, about

    var id: Self { self }

    var label: String {
        switch self {
        case .general: "通用"
        case .advanced: "高级"
        case .about: "关于"
        }
    }

    var systemImage: String {
        switch self {
        case .general: "gearshape"
        case .advanced: "slider.horizontal.3"
        case .about: "info.circle"
        }
    }
}

@MainActor
@Observable
final class SettingsNavigation {
    var page: SettingsPage? = .general
}

struct SettingsView: View {
    let navigation: SettingsNavigation
    let settings: AppSettings

    var body: some View {
        NavigationSplitView {
            List(selection: Binding(get: { navigation.page }, set: { navigation.page = $0 })) {
                ForEach(SettingsPage.allCases) { page in
                    Label(page.label, systemImage: page.systemImage)
                        .tag(page)
                }
            }
            .navigationSplitViewColumnWidth(180)
            .toolbar(removing: .sidebarToggle)
        } detail: {
            switch navigation.page ?? .general {
            case .general: GeneralSettings(settings: settings)
            case .advanced: AdvancedSettings(settings: settings)
            case .about: AboutSettings()
            }
        }
        .frame(width: 640, height: 420)
    }
}

/// `@Bindable` isn't available without the SwiftUI macros plugin, so bindings are built by hand.
@MainActor
private func binding<Value>(_ settings: AppSettings, _ keyPath: ReferenceWritableKeyPath<AppSettings, Value>) -> Binding<Value> {
    Binding(get: { settings[keyPath: keyPath] }, set: { settings[keyPath: keyPath] = $0 })
}

private struct GeneralSettings: View {
    let settings: AppSettings

    var body: some View {
        Form {
            Section {
                Picker("涨跌配色", selection: binding(settings, \.colorScheme)) {
                    ForEach(PriceColorScheme.allCases) { Text($0.label).tag($0) }
                }
                Toggle("开机自动启动", isOn: Binding(
                    get: { settings.launchesAtLogin },
                    set: { settings.setLaunchesAtLogin($0) }
                ))
                .toggleStyle(.switch)
            }

            Section {
                Toggle("在菜单栏显示价格", isOn: binding(settings, \.showsMenuBarPrices))
                    .toggleStyle(.switch)
                Picker("显示内容", selection: binding(settings, \.menuBarContent)) {
                    ForEach(MenuBarContent.allCases) { Text($0.label).tag($0) }
                }
                .disabled(!settings.showsMenuBarPrices)
                Picker("滚动间隔", selection: binding(settings, \.scrollInterval)) {
                    ForEach(AppSettings.scrollIntervalOptions, id: \.self) { Text("\($0) 秒").tag($0) }
                }
                .disabled(!settings.showsMenuBarPrices)
            }
        }
        .formStyle(.grouped)
    }
}

private struct AdvancedSettings: View {
    let settings: AppSettings

    var body: some View {
        Form {
            Section {
                Picker("后台刷新间隔", selection: binding(settings, \.refreshInterval)) {
                    ForEach(AppSettings.refreshIntervalOptions, id: \.self) { Text("\($0) 秒").tag($0) }
                }
            } footer: {
                Text("面板打开时每 5 秒刷新一次；休市期间自动暂停刷新。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle("显示盘前盘后价格", isOn: binding(settings, \.showsExtendedHours))
                    .toggleStyle(.switch)
            } footer: {
                Text("关闭后列表和详情页不再显示盘前盘后行情，菜单栏显示常规交易时段价格。")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct AboutSettings: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "开发版"
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
            Text("Kurumi")
                .font(.system(size: 18, weight: .semibold))
            Text("版本 \(version)")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Link("在 GitHub 上查看", destination: URL(string: "https://github.com/ksora94/kurumi")!)
                .font(.system(size: 12))
                .pointerCursor()
                .padding(.top, 4)
            Text("行情数据来自 Yahoo Finance 公开接口，可能存在延迟，仅供参考，不构成任何投资建议。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
