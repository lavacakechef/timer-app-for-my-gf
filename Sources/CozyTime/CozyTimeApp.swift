import CozyCore
import AppKit
import Foundation
import SwiftUI

@main
struct CozyTimeApp: App {
    @NSApplicationDelegateAdaptor(CozyAppDelegate.self) private var appDelegate
    @StateObject private var dataStore: AppDataStore
    @StateObject private var timerStore: FocusTimerStore
    @StateObject private var notifications: NotificationService
    @StateObject private var statusBarController: StatusBarController
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName

    init() {
        UserDefaults.standard.register(defaults: [
            "mascotName": "Mochi",
            "showMenuBarExtra": true,
            "appearanceMode": "system",
            "selectedTheme": CozyTheme.defaultName,
            "selectedMascotStyle": CozyMascotStyle.defaultID,
            "selectedTimerSkin": CozyTimerSkin.defaultID,
            "selectedTimerShape": CozyTimerShape.ring.rawValue,
            "showMotivationQuotes": true,
            "quoteStyle": CozyQuoteStyle.cozy.rawValue,
            "soundsEnabled": true
        ])
        Self.upgradeDefaultMascotNameIfNeeded()
        Self.upgradeDefaultThemeIfNeeded()
        Self.resetUITestingPreferencesIfNeeded()
        let appDataStore = AppDataStore()
        let appTimerStore = FocusTimerStore(defaults: Self.timerDefaults())
        Self.seedUITestingRewardTimerIfNeeded(timerStore: appTimerStore)
        let appNotifications = NotificationService()
        _dataStore = StateObject(wrappedValue: appDataStore)
        _timerStore = StateObject(wrappedValue: appTimerStore)
        _notifications = StateObject(wrappedValue: appNotifications)
        _statusBarController = StateObject(
            wrappedValue: StatusBarController(
                dataStore: appDataStore,
                timerStore: appTimerStore,
                notifications: appNotifications
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(dataStore)
                .environmentObject(timerStore)
                .environmentObject(notifications)
                .preferredColorScheme(Self.preferredColorScheme(for: appearanceMode))
                .tint(CozyTheme.named(selectedTheme).accent)
                .frame(minWidth: 1040, minHeight: 680)
                .onAppear {
                    statusBarController.setVisible(showMenuBarExtra)
                }
                .onChange(of: showMenuBarExtra) { _, isVisible in
                    statusBarController.setVisible(isVisible)
                }
                .onReceive(NotificationCenter.default.publisher(for: .cozyRootViewReady)) { _ in
                    CozyAppDelegate.flushPendingSectionOpen()
                }
        }
        .defaultSize(width: 1120, height: 760)
        .commands {
            CozyCommands(timerStore: timerStore, notifications: notifications)
        }

        Settings {
            SettingsScreen()
                .environmentObject(dataStore)
                .environmentObject(timerStore)
                .environmentObject(notifications)
                .preferredColorScheme(Self.preferredColorScheme(for: appearanceMode))
                .tint(CozyTheme.named(selectedTheme).accent)
                .frame(width: 560)
        }
    }

    private static func timerDefaults() -> UserDefaults {
        guard ProcessInfo.processInfo.arguments.contains("-ui-testing"),
              let defaults = UserDefaults(suiteName: "dev.local.cozytime.ui-testing") else {
            return .standard
        }
        defaults.removePersistentDomain(forName: "dev.local.cozytime.ui-testing")
        return defaults
    }

    private static func resetUITestingPreferencesIfNeeded() {
        guard ProcessInfo.processInfo.arguments.contains("-ui-testing") else { return }
        let defaults = UserDefaults.standard
        if let bundleIdentifier = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: bundleIdentifier)
        }
        defaults.set(true, forKey: "showMenuBarExtra")
        defaults.set("system", forKey: "appearanceMode")
        defaults.set(CozyTheme.defaultName, forKey: "selectedTheme")
        defaults.set(CozyMascotStyle.defaultID, forKey: "selectedMascotStyle")
        defaults.set(CozyTimerSkin.defaultID, forKey: "selectedTimerSkin")
        defaults.set(CozyTimerShape.ring.rawValue, forKey: "selectedTimerShape")
        defaults.set(true, forKey: "showMotivationQuotes")
        defaults.set(CozyQuoteStyle.cozy.rawValue, forKey: "quoteStyle")
        defaults.set("Mochi", forKey: "mascotName")
        defaults.set(false, forKey: "reducedDecoration")
        defaults.set(false, forKey: "hideStreaks")
        defaults.set(true, forKey: "soundsEnabled")
    }

    private static func seedUITestingRewardTimerIfNeeded(timerStore: FocusTimerStore) {
        guard ProcessInfo.processInfo.arguments.contains("-ui-testing-reward-ready") else { return }
        let now = Date()
        UserDefaults.standard.set(FocusBoost.default.id, forKey: "focus.activeBoostID")
        timerStore.start(taskTitle: "UI reward proof", duration: 5 * 60, at: now.addingTimeInterval(-5 * 60))
        timerStore.complete(at: now)
    }

    private static func upgradeDefaultMascotNameIfNeeded() {
        let defaults = UserDefaults.standard
        if defaults.string(forKey: "mascotName") == "Nimbus" {
            defaults.set("Mochi", forKey: "mascotName")
        }
    }

    private static func upgradeDefaultThemeIfNeeded() {
        let defaults = UserDefaults.standard
        let selectedTheme = defaults.string(forKey: "selectedTheme")
        if selectedTheme == nil || selectedTheme == "Jade Desk" {
            defaults.set(CozyTheme.defaultName, forKey: "selectedTheme")
        }
    }

    private static func preferredColorScheme(for appearanceMode: String) -> ColorScheme? {
        switch appearanceMode {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }
}

final class CozyAppDelegate: NSObject, NSApplicationDelegate {
    @MainActor private static var pendingSectionToOpen: AppSection?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.scheduleMainWindowOpen(after: 0.35)
        Self.scheduleMainWindowOpen(after: 1.0)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Task { @MainActor in
            Self.openMainWindowIfNeeded()
        }
        return true
    }

    @MainActor
    static func openMainWindowIfNeeded(retryIfNeeded: Bool = true) {
        let visibleWindow = NSApp.windows.first { window in
            window.isVisible && !window.isMiniaturized && window.canBecomeMain
        }

        if let visibleWindow {
            NSApp.activate(ignoringOtherApps: true)
            visibleWindow.makeKeyAndOrderFront(nil)
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        let didOpenWindow = NSApp.sendAction(#selector(NSResponder.newWindowForTab(_:)), to: nil, from: nil)
            || NSApp.sendAction(Selector(("newWindow:")), to: nil, from: nil)

        guard retryIfNeeded, !didOpenWindow else { return }
        scheduleMainWindowOpen(after: 0.35, retryIfNeeded: false)
    }

    @MainActor
    static func openSection(_ section: AppSection) {
        pendingSectionToOpen = section
        let hasVisibleMainWindow = NSApp.windows.contains { window in
            window.isVisible && !window.isMiniaturized && window.canBecomeMain
        }
        openMainWindowIfNeeded()
        if hasVisibleMainWindow {
            flushPendingSectionOpen()
        }
    }

    @MainActor
    static func flushPendingSectionOpen() {
        guard let section = pendingSectionToOpen else { return }
        pendingSectionToOpen = nil
        NotificationCenter.default.post(name: .cozyOpenSection, object: section.rawValue)
    }

    private static func scheduleMainWindowOpen(after delay: TimeInterval, retryIfNeeded: Bool = true) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            Task { @MainActor in
                Self.openMainWindowIfNeeded(retryIfNeeded: retryIfNeeded)
            }
        }
    }
}
