import CozyCore
import AppKit
import Foundation
import SwiftUI
import UserNotifications

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
    @AppStorage("hasCompletedFirstRun") private var hasCompletedFirstRun = false

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
        let appStatusBarController = StatusBarController(
            dataStore: appDataStore,
            timerStore: appTimerStore,
            notifications: appNotifications
        )
        _dataStore = StateObject(wrappedValue: appDataStore)
        _timerStore = StateObject(wrappedValue: appTimerStore)
        _notifications = StateObject(wrappedValue: appNotifications)
        _statusBarController = StateObject(wrappedValue: appStatusBarController)
        appDelegate.configure(
            dataStore: appDataStore,
            timerStore: appTimerStore,
            notifications: appNotifications,
            statusBarController: appStatusBarController
        )
    }

    var body: some Scene {
        Window("CozyTime", id: "main") {
            CozyMainWindowContent(
                dataStore: dataStore,
                timerStore: timerStore,
                notifications: notifications,
                statusBarController: statusBarController
            )
        }
        .defaultSize(width: 1120, height: 760)
        .defaultLaunchBehavior(.presented)
        .restorationBehavior(.disabled)
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
        guard Self.isUITesting,
              let defaults = UserDefaults(suiteName: "dev.local.cozytime.ui-testing") else {
            return .standard
        }
        defaults.removePersistentDomain(forName: "dev.local.cozytime.ui-testing")
        return defaults
    }

    private static func resetUITestingPreferencesIfNeeded() {
        guard Self.isUITesting else { return }
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
        // Skip first-run onboarding in UI tests so existing flow tests don't
        // race the modal sheet.
        defaults.set(true, forKey: "hasCompletedFirstRun")
    }

    private static func seedUITestingRewardTimerIfNeeded(timerStore: FocusTimerStore) {
        guard ProcessInfo.processInfo.arguments.contains("-ui-testing-reward-ready") else { return }
        let now = Date()
        UserDefaults.standard.set(FocusBoost.default.id, forKey: "focus.activeBoostID")
        timerStore.start(taskTitle: "UI reward proof", duration: 5 * 60, at: now.addingTimeInterval(-5 * 60))
        timerStore.complete(at: now)
    }

    fileprivate static var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-testing")
            || ProcessInfo.processInfo.environment["COZYTIME_UI_TESTING"] == "1"
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

    fileprivate static func preferredColorScheme(for appearanceMode: String) -> ColorScheme? {
        switch appearanceMode {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }
}

private struct CozyMainWindowContent: View {
    @ObservedObject var dataStore: AppDataStore
    @ObservedObject var timerStore: FocusTimerStore
    @ObservedObject var notifications: NotificationService
    @ObservedObject var statusBarController: StatusBarController
    @AppStorage("showMenuBarExtra") private var showMenuBarExtra = true
    @AppStorage("appearanceMode") private var appearanceMode = "system"
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    @AppStorage("hasCompletedFirstRun") private var hasCompletedFirstRun = false

    var body: some View {
        RootView()
            .environmentObject(dataStore)
            .environmentObject(timerStore)
            .environmentObject(notifications)
            .preferredColorScheme(CozyTimeApp.preferredColorScheme(for: appearanceMode))
            .tint(CozyTheme.named(selectedTheme).accent)
            // UX HIGH #82: minWidth was 1120 which blocked Stage Manager /
            // split-view / iPad sidecar workflows on the M2 Air. Lowering
            // to 720 lets the user collapse the window to a portrait-ish
            // width; .defaultSize keeps the launch geometry at 1120.
            .frame(minWidth: 720, minHeight: 600)
            .sheet(isPresented: Binding(
                get: { !CozyTimeApp.isUITesting && !hasCompletedFirstRun },
                set: { _ in }
            )) {
                FirstRunNamePrompt(hasCompleted: $hasCompletedFirstRun)
                    .interactiveDismissDisabled()
            }
            .onAppear {
                statusBarController.setVisible(showMenuBarExtra)
            }
            .onChange(of: showMenuBarExtra) { _, isVisible in
                statusBarController.setVisible(isVisible)
            }
            .onReceive(NotificationCenter.default.publisher(for: .cozyRootViewReady)) { _ in
                CozyAppDelegate.flushPendingSectionOpen()
            }
            .onReceive(NotificationCenter.default.publisher(for: .cozyDidWakeFromSleep)) { _ in
                // Refresh timer state immediately on wake so the menu bar / running
                // timer doesn't show a stale value for ~1s before the next Combine tick.
                timerStore.refreshCompletion(at: Date())
            }
    }
}

final class CozyAppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    @MainActor private static var pendingSectionToOpen: AppSection?
    @MainActor private static var dataStore: AppDataStore?
    @MainActor private static var timerStore: FocusTimerStore?
    @MainActor private static var notifications: NotificationService?
    @MainActor private static var statusBarController: StatusBarController?
    @MainActor private static var fallbackMainWindow: NSWindow?

    @MainActor
    func configure(dataStore: AppDataStore,
                   timerStore: FocusTimerStore,
                   notifications: NotificationService,
                   statusBarController: StatusBarController) {
        Self.dataStore = dataStore
        Self.timerStore = timerStore
        Self.notifications = notifications
        Self.statusBarController = statusBarController
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Become the notification delegate so tapping a "Time for a tiny win" or countdown
        // reminder actually opens the app and lands on the relevant section, rather than
        // blinking the Dock icon and going back to background. (Blindspot B1.)
        UNUserNotificationCenter.current().delegate = self

        // Re-sync timer state on wake. Combine's `Timer.publish` suspends with the runloop
        // during sleep, so the menu-bar timer freezes for ~1 second after waking before
        // catching up. Listening for didWakeNotification lets us snap to the right state
        // immediately. (Blindspot B3.)
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(self,
                              selector: #selector(handleDidWake(_:)),
                              name: NSWorkspace.didWakeNotification,
                              object: nil)

        Self.scheduleMainWindowOpen(after: 0.35)
        Self.scheduleMainWindowOpen(after: 1.0)
    }

    @objc private func handleDidWake(_ notification: Notification) {
        Task { @MainActor in
            // Nudge whichever view is bound to the timer to refresh on wake.
            NotificationCenter.default.post(name: .cozyDidWakeFromSleep, object: nil)
        }
    }

    // MARK: UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            willPresent notification: UNNotification,
                                            withCompletionHandler completionHandler:
                                              @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show the banner + sound even when CozyTime is in the foreground; otherwise the
        // user would never see her own completion notification while she's actively using
        // the app.
        completionHandler([.banner, .sound, .list])
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter,
                                            didReceive response: UNNotificationResponse,
                                            withCompletionHandler completionHandler:
                                              @escaping () -> Void) {
        // Call the completion handler synchronously to keep it off the @MainActor task
        // boundary (Swift 6 strict concurrency doesn't let us safely send the handler).
        // The actual section-open work runs after.
        let identifier = response.notification.request.identifier
        completionHandler()
        Task { @MainActor in
            // Identifier conventions live in NotificationPlanner:
            //   "focus-complete-<uuid>" → land on Focus to claim the reward
            //   "countdown-<eventID>-<daysBefore>" → land on Countdowns to see the event
            if identifier.hasPrefix("focus-complete-") {
                Self.openSection(.focus)
            } else if identifier.hasPrefix("countdown-") {
                Self.openSection(.countdowns)
            } else {
                Self.openMainWindowIfNeeded()
            }
        }
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

        if let fallbackMainWindow {
            NSApp.activate(ignoringOtherApps: true)
            fallbackMainWindow.makeKeyAndOrderFront(nil)
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        // B2: prefer the documented `newWindowForTab:` selector. The
        // undocumented `newWindow:` selector previously chained here is not
        // guaranteed across macOS majors — fall through to
        // `presentFallbackMainWindow()` instead (which is a deterministic
        // SwiftUI-driven path that we own and can always rely on).
        let didOpenWindow = NSApp.sendAction(#selector(NSResponder.newWindowForTab(_:)), to: nil, from: nil)

        if didOpenWindow {
            scheduleMainWindowOpen(after: 0.25, retryIfNeeded: false)
            return
        }

        if presentFallbackMainWindow() {
            return
        }

        guard retryIfNeeded else { return }
        scheduleMainWindowOpen(after: 0.35, retryIfNeeded: false)
    }

    @MainActor
    @discardableResult
    private static func presentFallbackMainWindow() -> Bool {
        guard let dataStore,
              let timerStore,
              let notifications,
              let statusBarController else {
            return false
        }

        let rootView = CozyMainWindowContent(
            dataStore: dataStore,
            timerStore: timerStore,
            notifications: notifications,
            statusBarController: statusBarController
        )
        let hostingController = NSHostingController(rootView: rootView)
        let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 820)
        let windowSize = NSSize(width: 1120, height: 760)
        let origin = NSPoint(
            x: screenFrame.midX - windowSize.width / 2,
            y: screenFrame.midY - windowSize.height / 2
        )
        let window = NSWindow(
            contentRect: NSRect(origin: origin, size: windowSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "CozyTime"
        window.minSize = NSSize(width: 1120, height: 720)
        window.contentViewController = hostingController
        window.setFrameAutosaveName("CozyTimeMainWindow")
        fallbackMainWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        return true
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

// First-run onboarding sheet — researched recipe (M3). NN/g on mobile
// onboarding: "Avoid feature-promotion onboarding at first launch... minimize
// the number of cards to only focus on need-to-know information." Finch's
// egg-naming triad collapsed to ONE decision (mascot name) — the lightest
// friction-to-personalization step. Skippable. Defaults to "Mochi" so doing
// nothing still ships a usable app.
struct FirstRunNamePrompt: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("mascotName") private var mascotName = "Mochi"
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    @State private var draft = "Mochi"
    @Binding var hasCompleted: Bool

    private var theme: CozyTheme {
        CozyTheme.named(selectedTheme)
    }

    private var displayName: String {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Mochi" : String(trimmed.prefix(24))
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                MascotView(state: .idle, size: .hero)
                    .accessibilityHidden(true)

                VStack(spacing: 6) {
                    // Explicit foregroundStyle is required — without it, the title
                    // inherits an ambient near-white color from the sheet host on
                    // macOS and disappears against the cream canvas. Previous fix
                    // used theme.canvas as the background (≈ #FFF9F7) AND no
                    // explicit text color, giving white-on-white invisibility.
                    Text("Hi — what should we call your cozy buddy?")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(CozyPalette.primaryText(colorScheme))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("You can rename them any time in Settings.")
                        .font(.callout)
                        .foregroundStyle(CozyPalette.secondaryText(colorScheme))
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                TextField("Mochi", text: $draft)
                    .cozyTextInput(width: 240, alignment: .leading)
                    .foregroundStyle(CozyPalette.primaryText(colorScheme))
                    .onSubmit { save() }
                    .accessibilityIdentifier("firstRun.name.field")

                Button {
                    save()
                } label: {
                    Label("Hi, \(displayName)", systemImage: "pawprint.fill")
                        .frame(maxWidth: 220)
                }
                .cozyPrimaryButton(minWidth: 220)
                .keyboardShortcut(.defaultAction)
                .accessibilityIdentifier("firstRun.save")

                Button("Skip for now") { save(skipped: true) }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(CozyPalette.secondaryText(colorScheme))
                    .accessibilityIdentifier("firstRun.skip")
            }
            .padding(32)
        }
        .frame(minWidth: 400, idealWidth: 400, maxWidth: 440, minHeight: 440, idealHeight: 460, maxHeight: 560)
        // Card-style sheet with hairline border — clearly separates the
        // modal from the canvas behind it AND gives the text content a
        // background with documented contrast against primaryText.
        .background(
            RoundedRectangle(cornerRadius: CozyLayout.cardRadius, style: .continuous)
                .fill(CozyPalette.cardFill(colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: CozyLayout.cardRadius, style: .continuous)
                        .stroke(CozyPalette.cardBorder(colorScheme), lineWidth: 1)
                )
                .shadow(color: CozyPalette.lofiInk.opacity(colorScheme == .dark ? 0.30 : 0.08), radius: 18, y: 8)
        )
        .accessibilityAddTraits(.isModal)
    }

    private func save(skipped: Bool = false) {
        if !skipped {
            mascotName = displayName
        }
        hasCompleted = true
    }
}
