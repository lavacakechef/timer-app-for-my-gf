// UX HIGH #79: First-run coachmark tour. Shown once, AFTER the
// FirstRunNamePrompt sheet, AFTER the user has named Mochi. Three pages,
// each one decision lighter than the last — pick a task → start a focus →
// earn paws. Mascot stays cute and reassuring; copy avoids streak-shaming.
//
// UX HIGH #83: First-time micro-celebration toast. Mochi "notices" the very
// first task completed, focus finished, and habit checked. Wiring lives in
// the relevant feature views (see TODO below); this file owns the
// presentation primitive + the @AppStorage gates so the gates can't drift
// out of sync.
//
// TODO(UX-83-wireup): present FirstMomentToast from:
//   - TaskViews:        when a task is marked complete for the first time
//                       (gate on `hasCompletedFirstTask`)
//   - FocusViews:       when a focus session finishes for the first time
//                       (gate on `hasFinishedFirstFocus`)
//   - HabitStatsViews:  when a habit is checked off for the first time
//                       (gate on `hasCheckedFirstHabit`)
// Each wiring site should set its `@AppStorage` flag to true the moment it
// fires the toast so we only ever congratulate the very first instance.

import SwiftUI

// MARK: - Coachmark tour

/// First-run coachmark sheet. Three pages, skippable on every page, sets
/// `hasSeenCoachmark = true` on completion (or skip). Honors Reduce Motion
/// for both the mascot art (Lottie → SF Symbol fallback) and the page
/// transition (no horizontal slide; the TabView's default page-style
/// transition becomes an instant change, which is what we want).
struct FirstRunCoachmarkSheet: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedMascotStyle") private var selectedMascotStyle = CozyMascotStyle.defaultID
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName
    @AppStorage("hasSeenCoachmark", store: .standard) private var hasSeenCoachmark = false

    @State private var pageIndex = 0

    private static let pages: [CoachmarkPage] = [
        CoachmarkPage(
            title: "Pick a task",
            body: "Add what you want to focus on — even just one tiny thing. Mochi will keep time with you.",
            mascotState: .idle,
            accentSymbol: "checklist",
            ctaTitle: "Next"
        ),
        CoachmarkPage(
            title: "Start a focus",
            body: "Tap Start. Even 1 minute counts. Pause anytime — Mochi understands.",
            mascotState: .focus,
            accentSymbol: "play.circle.fill",
            ctaTitle: "Next"
        ),
        CoachmarkPage(
            title: "Earn paws → decorate",
            body: "Each block earns paws. Spend them in the Shop to decorate Mochi's room.",
            mascotState: .complete,
            accentSymbol: "sparkles",
            ctaTitle: "Let's go"
        )
    ]

    var body: some View {
        ZStack {
            // Tab content. `.tabViewStyle(.automatic)` keeps the default
            // page indicators (where supported) — we also render our own
            // dot row so the visual is consistent on macOS.
            TabView(selection: $pageIndex) {
                ForEach(Array(Self.pages.enumerated()), id: \.offset) { index, page in
                    coachmarkPageView(page: page, index: index)
                        .tag(index)
                }
            }
            .tabViewStyle(.automatic)
        }
        .frame(idealWidth: CozyLayout.sheetIdealWidthMedium, idealHeight: CozyLayout.sheetIdealHeightMedium)
        .background(
            RoundedRectangle(cornerRadius: CozyLayout.cardRadius, style: .continuous)
                .fill(CozyPalette.cardFill(colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: CozyLayout.cardRadius, style: .continuous)
                        .stroke(CozyPalette.cardBorder(colorScheme), lineWidth: 1)
                )
        )
        // Visual-audit fix: previously had both CozySheetDismissAffordance
        // (an X in the top-right corner) AND a "Skip tour" link in the page
        // content — the two stacked. Skip tour is more discoverable for a
        // first-run tour, so we keep it and add the Escape shortcut to it
        // directly (see the Skip tour Button below) instead of using the X.
        .accessibilityAddTraits(.isModal)
        .accessibilityIdentifier("firstRun.coachmark")
    }

    @ViewBuilder
    private func coachmarkPageView(page: CoachmarkPage, index: Int) -> some View {
        let theme = CozyTheme.named(selectedTheme)

        VStack(spacing: 0) {
            // Top row — Skip tour, right-aligned. Single dismiss affordance
            // (Esc keyboard shortcut wired below). Was previously duplicated
            // with the sheet X button which stacked weirdly.
            HStack {
                Spacer()
                Button("Skip tour") { finish() }
                    .buttonStyle(.plain)
                    .font(CozyType.captionStrong)
                    .foregroundStyle(CozyPalette.secondaryText(colorScheme))
                    .padding(.horizontal, CozyLayout.badgePaddingMediumH)
                    .padding(.vertical, CozyLayout.badgePaddingLargeV)
                    .background(
                        Capsule().fill(CozyPalette.quietContainer(colorScheme).opacity(0.6))
                    )
                    .keyboardShortcut(.cancelAction)
                    .accessibilityIdentifier("firstRun.coachmark.skip")
            }
            .padding(.bottom, 8)

            Spacer(minLength: 0)

            // Hero stack — mascot is the star; accent badge moved to a
            // sticker-style overlay on the bottom-right of the mascot frame
            // so it reads as a piece of one composition rather than two
            // disconnected icons floating in space.
            ZStack(alignment: .bottomTrailing) {
                coachmarkMascot(state: page.mascotState)
                    .frame(width: 160, height: 160)
                    .accessibilityHidden(true)

                ZStack {
                    Circle()
                        .fill(theme.accent)
                        .shadow(color: theme.accent.opacity(0.35), radius: 8, y: 2)
                    Image(systemName: page.accentSymbol)
                        .font(CozyType.cardTitle)
                        .foregroundStyle(theme.foregroundOnAccent(colorScheme))
                }
                .frame(width: 44, height: 44)
                .offset(x: 4, y: 4)
            }
            .accessibilityHidden(true)

            VStack(spacing: 12) {
                Text(page.title)
                    .font(CozyType.heroCardTitle)
                    .foregroundStyle(CozyPalette.primaryText(colorScheme))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(page.body)
                    .font(CozyType.body)
                    .foregroundStyle(CozyPalette.secondaryText(colorScheme))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.horizontal, 16)
            }
            .padding(.top, 20)

            Spacer(minLength: 0)

            // Page-dot indicator. Selected dot is a wider pill (16×8) so the
            // user can read progress at a glance; inactive dots are 8×8.
            HStack(spacing: 8) {
                ForEach(0..<Self.pages.count, id: \.self) { dotIndex in
                    Capsule()
                        .fill(
                            dotIndex == index
                                ? theme.accent
                                : CozyPalette.secondaryText(colorScheme).opacity(0.28)
                        )
                        .frame(width: dotIndex == index ? 20 : 8, height: 8)
                        .animation(CozyMotion.snappy(reduceMotion, duration: 0.22), value: index)
                }
            }
            .padding(.bottom, 16)
            .accessibilityHidden(true)

            Button {
                advance()
            } label: {
                Text(page.ctaTitle)
                    .frame(maxWidth: .infinity)
            }
            .cozyPrimaryButton(fullWidth: true)
            .keyboardShortcut(.defaultAction)
            .accessibilityIdentifier("firstRun.coachmark.cta.page\(index)")
        }
        .padding(CozyLayout.cardPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    @ViewBuilder
    private func coachmarkMascot(state: MascotState) -> some View {
        let style = CozyMascotStyle.named(selectedMascotStyle)
        if !reduceMotion,
           let lottieCharacter = CozyLottieMascot.lottiePrefix(forStyleID: style.id),
           CozyLottieMascot.isBundled(character: lottieCharacter) {
            CozyLottieMascot(characterID: lottieCharacter, state: state, size: 140)
        } else {
            // Reduce Motion / no bundled Lottie — fall back to the
            // mascot's SF Symbol so the page still has a friendly face.
            let theme = CozyTheme.named(selectedTheme)
            Image(systemName: style.symbolName)
                .font(CozyType.metric)
                .foregroundStyle(theme.tintedText(colorScheme))
                .padding(20)
                .background(
                    Circle().fill(theme.surfaceTint.opacity(colorScheme == .dark ? 0.18 : 0.42))
                )
        }
    }

    private func advance() {
        if pageIndex >= Self.pages.count - 1 {
            finish()
        } else {
            withAnimation(CozyMotion.snappy(reduceMotion)) {
                pageIndex += 1
            }
        }
    }

    private func finish() {
        hasSeenCoachmark = true
    }
}

private struct CoachmarkPage {
    let title: String
    let body: String
    let mascotState: MascotState
    let accentSymbol: String
    let ctaTitle: String
}

// MARK: - First-moment celebration toast

/// "Mochi noticed!" toast — a single-line celebratory overlay shown the
/// very first time the user completes a task, finishes a focus block, or
/// checks a habit. Caller is responsible for gating on the matching
/// `@AppStorage` flag declared below; this view is purely presentational.
///
/// The toast fades + (when motion is allowed) scales in from 0.92 → 1.0.
/// Reduce Motion users get a static fade only.
struct FirstMomentToast: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("selectedTheme") private var selectedTheme = CozyTheme.defaultName

    /// Bind to a host-owned visibility flag; the host is expected to flip
    /// this true on the first event and then false after a short delay
    /// (1.6–2.0s reads cozy without lingering).
    @Binding var isPresented: Bool

    /// Custom copy. Defaults to the canonical "Mochi noticed!" line so
    /// callers can keep the wiring trivial.
    var message: String = "Mochi noticed!"

    var body: some View {
        let theme = CozyTheme.named(selectedTheme)

        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(CozyType.controlStrong)
                .foregroundStyle(theme.rewardText(colorScheme))
            Text(message)
                .font(CozyType.captionStrong)
                .foregroundStyle(CozyPalette.primaryText(colorScheme))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: CozyLayout.cardRadius, style: .continuous)
                .fill(CozyPalette.cardFill(colorScheme))
                .overlay(
                    RoundedRectangle(cornerRadius: CozyLayout.cardRadius, style: .continuous)
                        .stroke(theme.accent.opacity(0.32), lineWidth: 1)
                )
                .shadow(color: CozyPalette.softShadow(colorScheme, active: true), radius: 12, y: 4)
        )
        .scaleEffect(reduceMotion ? 1.0 : (isPresented ? 1.0 : 0.92))
        .opacity(isPresented ? 1.0 : 0.0)
        .animation(CozyMotion.snappy(reduceMotion), value: isPresented)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(message)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityIdentifier("firstMoment.toast")
    }
}

/// Centralized first-moment AppStorage gates. Co-located with the
/// presentation primitive so the keys and the toast stay in lock-step.
/// The wiring sites listed in the file header read/write these flags.
struct FirstMomentGates {
    @AppStorage("hasCompletedFirstTask") var hasCompletedFirstTask = false
    @AppStorage("hasFinishedFirstFocus") var hasFinishedFirstFocus = false
    @AppStorage("hasCheckedFirstHabit") var hasCheckedFirstHabit = false
}
