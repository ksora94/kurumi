import AppKit
import Observation
import SwiftUI

enum SettingsPage: String, CaseIterable, Identifiable {
    case general, advanced, about

    var id: Self { self }

    @MainActor var label: String {
        switch self {
        case .general: Loc.general
        case .advanced: Loc.advanced
        case .about: Loc.about
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
                Picker(Loc.language, selection: binding(settings, \.languagePreference)) {
                    ForEach(LanguagePreference.allCases) { Text($0.label).tag($0) }
                }
                Picker(Loc.colorScheme, selection: binding(settings, \.colorScheme)) {
                    ForEach(PriceColorScheme.allCases) { Text($0.label).tag($0) }
                }
                Toggle(Loc.launchAtLogin, isOn: Binding(
                    get: { settings.launchesAtLogin },
                    set: { settings.setLaunchesAtLogin($0) }
                ))
                .toggleStyle(.switch)
            }

            Section {
                Toggle(Loc.showMenuBarPrices, isOn: binding(settings, \.showsMenuBarPrices))
                    .toggleStyle(.switch)
                Picker(Loc.menuBarContent, selection: binding(settings, \.menuBarContent)) {
                    ForEach(MenuBarContent.allCases) { Text($0.label).tag($0) }
                }
                .disabled(!settings.showsMenuBarPrices)
                Picker(Loc.scrollInterval, selection: binding(settings, \.scrollInterval)) {
                    ForEach(AppSettings.scrollIntervalOptions, id: \.self) { Text(Loc.seconds($0)).tag($0) }
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
                Picker(Loc.refreshInterval, selection: binding(settings, \.refreshInterval)) {
                    ForEach(AppSettings.refreshIntervalOptions, id: \.self) { Text(Loc.seconds($0)).tag($0) }
                }
            } footer: {
                Text(Loc.refreshFootnote)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Section {
                Toggle(Loc.showExtendedHours, isOn: binding(settings, \.showsExtendedHours))
                    .toggleStyle(.switch)
            } footer: {
                Text(Loc.extendedHoursFootnote)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}

private struct AboutSettings: View {
    private var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? Loc.developmentBuild
    }

    var body: some View {
        VStack(spacing: 8) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: 72, height: 72)
            Text("Kurumi")
                .font(.system(size: 18, weight: .semibold))
            Text(Loc.version(version))
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Link(Loc.viewOnGitHub, destination: URL(string: "https://github.com/ksora94/kurumi")!)
                .font(.system(size: 12))
                .pointerCursor()
                .padding(.top, 4)
            Text(Loc.disclaimer)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
                .padding(.top, 12)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
