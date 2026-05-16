import AppKit
import SwiftUI

// MARK: - Notification names

extension Notification.Name {
    /// Posted when the user invokes "Show keyboard shortcuts" from the Help menu
    /// (⌘?). Any view in the main window may subscribe to surface its own
    /// presentation — the default presenter is `KeyboardShortcutsWindowPresenter`
    /// which hosts a standalone panel so the cheatsheet works even when the main
    /// window content is not on screen.
    static let cozyShowKeyboardShortcuts = Notification.Name("CozyTimeShowKeyboardShortcuts")

    /// Posted when the user invokes "Focus quick-add" (⌘L). TaskViews
    /// subscribers will move first-responder to their inline quick-add field
    /// when present.
    /// TODO: subscriber side lives in TaskViews (TaskInbox quick-add bar).
    /// When that view mounts it should `.onReceive(...)` this notification
    /// and call `focusedField = .quickAdd` (or equivalent FocusState).
    static let cozyFocusQuickAdd = Notification.Name("CozyTimeFocusQuickAdd")

    /// Posted when the user invokes "New…" (⌘N) from the File menu. RootView
    /// resolves the active sidebar section and re-posts one of the
    /// section-scoped notifications below so each composer can subscribe
    /// without knowing about the others.
    static let cozyNewItem = Notification.Name("CozyTimeNewItem")

    /// Posted by RootView when ⌘N is pressed while a tasks-bearing section
    /// (Today, Tasks) is selected. TasksView / QuickAddBar moves first-
    /// responder to the inline task-title field.
    static let cozyNewTask = Notification.Name("CozyTimeNewTask")

    /// Posted by RootView when ⌘N is pressed while Habits is selected.
    /// HabitsView moves first-responder to its inline habit field.
    static let cozyNewHabit = Notification.Name("CozyTimeNewHabit")

    /// Posted by RootView when ⌘N is pressed while Calendar is selected
    /// (countdowns live there). CalendarPlannerView opens the countdown
    /// composer sheet.
    static let cozyNewCountdown = Notification.Name("CozyTimeNewCountdown")
}

// MARK: - Model

/// One row in the cheatsheet — shortcut chip on the left, action label on the right.
struct KeyboardShortcutEntry: Identifiable {
    let id = UUID()
    let keys: String
    let action: String
    /// Optional contextual qualifier ("when in Tasks", "when present", …)
    let context: String?

    init(_ keys: String, _ action: String, context: String? = nil) {
        self.keys = keys
        self.action = action
        self.context = context
    }
}

struct KeyboardShortcutSection: Identifiable {
    let id = UUID()
    let title: String
    let entries: [KeyboardShortcutEntry]
}

enum KeyboardShortcutCatalog {
    static let sections: [KeyboardShortcutSection] = [
        KeyboardShortcutSection(title: "Focus", entries: [
            KeyboardShortcutEntry("\u{2318}\u{21E7}F", "Start a focus session"),
            KeyboardShortcutEntry("\u{2318}\u{21E7}P", "Pause / resume focus"),
            KeyboardShortcutEntry("\u{2318}\u{21E7}.", "Discard focus")
        ]),
        KeyboardShortcutSection(title: "Navigation", entries: [
            KeyboardShortcutEntry("\u{2318}?", "Show this cheatsheet"),
            KeyboardShortcutEntry("\u{2318},", "Settings"),
            KeyboardShortcutEntry("\u{2318}W", "Close window"),
            KeyboardShortcutEntry("Esc", "Dismiss the topmost sheet or popover")
        ]),
        KeyboardShortcutSection(title: "Editing", entries: [
            KeyboardShortcutEntry("\u{2318}N", "New task", context: "when in Tasks"),
            KeyboardShortcutEntry("\u{2318}L", "Focus the quick-add field", context: "when present")
        ])
    ]
}

// MARK: - View

struct KeyboardShortcutsHelp: View {
    @Environment(\.colorScheme) private var colorScheme
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: CozyLayout.sectionSpacing) {
            header

            VStack(alignment: .leading, spacing: CozyLayout.sectionSpacing) {
                ForEach(KeyboardShortcutCatalog.sections) { section in
                    sectionView(section)
                }
            }
        }
        .padding(CozyLayout.cardPadding)
        .frame(
            minWidth: CozyLayout.sheetIdealWidthMedium,
            idealWidth: CozyLayout.sheetIdealWidthMedium,
            maxWidth: CozyLayout.sheetIdealWidthLarge,
            alignment: .topLeading
        )
        .background(
            RoundedRectangle(cornerRadius: CozyLayout.cardRadius, style: .continuous)
                .fill(CozyPalette.cardFill(colorScheme))
        )
        .foregroundStyle(CozyPalette.primaryText(colorScheme))
        .modifier(CozySheetDismissAffordance(dismiss: dismiss))
        .accessibilityIdentifier("sheet.keyboardShortcuts")
    }

    @ViewBuilder
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Keyboard Shortcuts")
                .font(CozyType.cardTitle)
            Text("Every CozyTime hotkey in one place.")
                .font(CozyType.body)
                .foregroundStyle(CozyPalette.secondaryText(colorScheme))
        }
    }

    @ViewBuilder
    private func sectionView(_ section: KeyboardShortcutSection) -> some View {
        VStack(alignment: .leading, spacing: CozyLayout.formRowSpacing) {
            Text(section.title.uppercased())
                .font(CozyType.captionStrong)
                .foregroundStyle(CozyPalette.secondaryText(colorScheme))

            VStack(alignment: .leading, spacing: CozyLayout.formRowSpacing) {
                ForEach(section.entries) { entry in
                    HStack(alignment: .firstTextBaseline, spacing: CozyLayout.gridSpacing) {
                        Text(entry.keys)
                            .font(CozyType.controlStrong.monospaced())
                            .foregroundStyle(CozyPalette.primaryText(colorScheme))
                            .frame(minWidth: 72, alignment: .leading)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.action)
                                .font(CozyType.rowTitle)
                                .foregroundStyle(CozyPalette.primaryText(colorScheme))
                            if let context = entry.context {
                                Text(context)
                                    .font(CozyType.caption)
                                    .foregroundStyle(CozyPalette.secondaryText(colorScheme))
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
        }
    }
}

// MARK: - Standalone window presenter

/// Hosts `KeyboardShortcutsHelp` inside a borderless utility panel so the
/// cheatsheet can be invoked from anywhere — Command menu, status bar, or
/// from a future in-window observer. We avoid binding the sheet directly to
/// RootView so the help works even before the main window is visible.
@MainActor
final class KeyboardShortcutsWindowPresenter {
    static let shared = KeyboardShortcutsWindowPresenter()

    private var window: NSWindow?

    private init() {
        // Singleton lives for the lifetime of the process, so we never
        // remove the observer — keeping a stored token would force the
        // deinit to reach back into MainActor state, which Swift 6 strict
        // concurrency rightfully refuses.
        NotificationCenter.default.addObserver(
            forName: .cozyShowKeyboardShortcuts,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in KeyboardShortcutsWindowPresenter.shared.present() }
        }
    }

    func present() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        let hosting = NSHostingController(
            rootView: KeyboardShortcutsHelp { [weak self] in self?.close() }
        )
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 480),
            styleMask: [.titled, .closable, .hudWindow, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "Keyboard Shortcuts"
        panel.contentViewController = hosting
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.center()
        panel.isReleasedWhenClosed = false
        window = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func close() {
        window?.close()
        window = nil
    }
}

// MARK: - Commands group

/// Replaces the system Help menu with a single "Keyboard Shortcuts…" item
/// bound to ⌘?. The button posts `.cozyShowKeyboardShortcuts`; the
/// `KeyboardShortcutsWindowPresenter` singleton hosts the sheet content.
struct KeyboardShortcutsCommand: Commands {
    var body: some Commands {
        CommandGroup(replacing: .help) {
            Button("Keyboard Shortcuts\u{2026}") {
                // Touch the singleton so its observer is wired before the
                // first post — accessing `.shared` is enough.
                _ = KeyboardShortcutsWindowPresenter.shared
                NotificationCenter.default.post(name: .cozyShowKeyboardShortcuts, object: nil)
            }
            .keyboardShortcut("?", modifiers: .command)
        }
    }
}
