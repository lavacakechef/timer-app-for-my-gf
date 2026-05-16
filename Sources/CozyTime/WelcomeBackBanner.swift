import Foundation
import SwiftUI

// Welcome-back banner — surfaced once per upgrade.
//
// Why it exists: CozyTime keeps its data in
// `~/Library/Application Support/CozyTime/CozyTime.store` (SwiftData) and in
// `~/Library/Preferences/dev.local.cozytime.plist`, both of which live outside
// the app bundle and therefore survive a Finder "Replace" of CozyTime.app.
// The engineering side of that is solid (see docs/MIGRATING.md), but the user
// has no way to *know* their data is safe — the app just opens as if nothing
// happened. That silent persistence reads as "did it forget me?" to a
// non-technical user.
//
// Pattern: compare `Bundle.main.infoDictionary?["CFBundleShortVersionString"]`
// (Apple's "release or version number of the bundle" — three period-separated
// integers, e.g. "1.0.0") against an `@AppStorage("lastSeenAppVersion")` value.
// First launch after an upgrade, the banner appears; the user dismisses it
// (or it auto-dismisses after a manual peek), the stored version catches up,
// and subsequent launches are silent.
//
// Visual rules (DESIGN_SYSTEM.md):
//   - Reuses CozyPalette / CozyLayout so dark mode + selected theme survive.
//   - Sits in the same top safe-area inset slot as `CozyDataStoreErrorBanner`,
//     but at a lower priority — if there is a real data error, the red error
//     banner wins and this view stays hidden.
//   - Never sad/punitive copy. Reassurance-only.

struct WelcomeBackBanner: View {
    /// Stored version-name from the LAST launch. Empty string on a clean
    /// install. The key is intentionally distinct from `hasCompletedFirstRun`
    /// so first-run onboarding still gets to play before this banner can
    /// possibly show.
    @AppStorage("lastSeenAppVersion") private var lastSeenAppVersion = ""
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Optional reassurance values supplied by the host view. Pass real
    /// counts from `AppDataStore` so the user sees "your 142 sessions are
    /// safe" rather than a generic message. Both default to nil; if both are
    /// nil the banner falls back to a non-numeric reassurance line.
    let focusSessionCount: Int?
    let unlockedRewardCount: Int?

    /// True the first time this build is launched. Becomes false again as
    /// soon as the user taps "Got it" (or the auto-dismiss timer fires).
    @State private var isVisible: Bool

    private static let currentVersion: String = {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "dev"
    }()

    init(focusSessionCount: Int? = nil, unlockedRewardCount: Int? = nil) {
        self.focusSessionCount = focusSessionCount
        self.unlockedRewardCount = unlockedRewardCount
        // Compute visibility once, at construction time, against the *current*
        // stored value. We don't want the banner to flicker back if the user
        // is mid-dismissal and another view triggers a redraw.
        let stored = UserDefaults.standard.string(forKey: "lastSeenAppVersion") ?? ""
        let current = Self.currentVersion
        let shouldShow = !stored.isEmpty && stored != current && current != "dev"
        _isVisible = State(initialValue: shouldShow)
    }

    var body: some View {
        Group {
            if isVisible {
                bannerContent
                    .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            } else {
                // Even when not visible, we still need to mark the current
                // version as seen — otherwise a freshly installed build
                // (stored == "") would loop the "no upgrade detected" path on
                // every launch without ever updating lastSeenAppVersion.
                Color.clear.frame(height: 0).onAppear(perform: markCurrentVersionSeen)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.25), value: isVisible)
    }

    private var bannerContent: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: "sparkles")
                .foregroundStyle(CozyPalette.focusJade)
                .imageScale(.medium)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(headline)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(CozyPalette.primaryText(colorScheme))
                Text(subline)
                    .font(.caption)
                    .foregroundStyle(CozyPalette.secondaryText(colorScheme))
            }
            Spacer(minLength: 8)
            Button("Got it") { dismiss() }
                .buttonStyle(.borderless)
                .font(.caption.weight(.semibold))
                .foregroundStyle(CozyPalette.focusJade)
                .accessibilityIdentifier("welcomeBack.dismiss")
        }
        .padding(.horizontal, CozyLayout.cardPadding)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(CozyPalette.focusJade.opacity(colorScheme == .dark ? 0.18 : 0.12))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Welcome back to CozyTime. \(headline). \(subline).")
        .accessibilityIdentifier("welcomeBack.banner")
    }

    private var headline: String {
        let stored = UserDefaults.standard.string(forKey: "lastSeenAppVersion") ?? ""
        if stored.isEmpty {
            return "Welcome back — CozyTime \(Self.currentVersion) is ready."
        }
        return "Welcome back — updated to CozyTime \(Self.currentVersion)."
    }

    private var subline: String {
        switch (focusSessionCount, unlockedRewardCount) {
        case let (sessions?, unlocks?) where sessions > 0 || unlocks > 0:
            return "Your \(sessions) focus sessions and \(unlocks) unlocks are all safe."
        case let (sessions?, _) where sessions > 0:
            return "Your \(sessions) focus sessions are all safe."
        case let (_, unlocks?) where unlocks > 0:
            return "Your \(unlocks) unlocks are still here."
        default:
            return "Your data, mascot, and themes are all still here."
        }
    }

    private func dismiss() {
        isVisible = false
        markCurrentVersionSeen()
    }

    private func markCurrentVersionSeen() {
        // Guard against bundles that somehow lack a version (Xcode previews,
        // dev SwiftPM run). Writing "dev" would mean a subsequent real build
        // is always treated as an upgrade — also fine, just noisy.
        guard Self.currentVersion != "dev" else { return }
        if lastSeenAppVersion != Self.currentVersion {
            lastSeenAppVersion = Self.currentVersion
        }
    }
}

#if DEBUG
#Preview("Welcome back — upgrade") {
    UserDefaults.standard.set("0.1.0", forKey: "lastSeenAppVersion")
    return WelcomeBackBanner(focusSessionCount: 142, unlockedRewardCount: 7)
        .padding(16)
}

#Preview("Welcome back — clean install (hidden)") {
    UserDefaults.standard.removeObject(forKey: "lastSeenAppVersion")
    return WelcomeBackBanner(focusSessionCount: 0, unlockedRewardCount: 0)
        .padding(16)
}
#endif
