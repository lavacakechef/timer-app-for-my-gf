import AppKit
import CozyCore
import SwiftUI

struct CozyCommands: Commands {
    let dataStore: AppDataStore
    let timerStore: FocusTimerStore
    let notifications: NotificationService

    var body: some Commands {
        CommandGroup(replacing: .undoRedo) {
            Button("Undo") {
                dataStore.undoManager.undo()
            }
            .keyboardShortcut("z", modifiers: .command)
            .disabled(!dataStore.undoManager.canUndo)

            Button("Redo") {
                dataStore.undoManager.redo()
            }
            .keyboardShortcut("z", modifiers: [.command, .shift])
            .disabled(!dataStore.undoManager.canRedo)
        }

        CommandMenu("Focus") {
            // Apple HIG: menu items use sentence case ("Start 25 min focus"), and a button
            // describes what it does rather than how (replaced "End Focus Gently" → "Discard
            // focus" so the user knows it doesn't save).
            Button("Start \(CozyFormatters.durationLabel(TimeInterval(rememberedFocusMinutes * 60))) focus") {
                timerStore.startRememberedQuickFocus()
                scheduleFocusCompletion()
            }
            .keyboardShortcut("f", modifiers: [.command, .shift])
            .disabled(!timerStore.canStartNewSession)

            Button(timerStore.isRunning ? "Pause focus" : "Resume focus") {
                if timerStore.isRunning {
                    timerStore.pause()
                    Task { await notifications.cancelFocusNotifications() }
                } else if timerStore.isPaused {
                    timerStore.resume()
                    scheduleFocusCompletion()
                }
            }
            .keyboardShortcut("p", modifiers: [.command, .shift])
            .disabled(!timerStore.isActive)

            Button("Discard focus") {
                timerStore.cancel()
                timerStore.reset(duration: TimeInterval(rememberedFocusMinutes * 60))
                Task { await notifications.cancelFocusNotifications() }
            }
            .keyboardShortcut(".", modifiers: [.command, .shift])
            .disabled(!timerStore.isActive)
        }

        // UX HIGH #85: AppKit normally provides ⌘W on the standard File menu's
        // "Close" item, but CozyTime uses a `Window` scene without that menu,
        // so the shortcut never reached `NSApp.keyWindow`. Re-add it via a
        // hidden window command group so users can dismiss the main window
        // (or any sheet) with the familiar chord.
        CommandGroup(after: .windowArrangement) {
            Button("Close Window") {
                NSApp.keyWindow?.performClose(nil)
            }
            .keyboardShortcut("w", modifiers: .command)
        }

        // UX HIGH #85 (sibling): ⌘N "New…" context-aware. Posts a generic
        // notification; RootView reads the active sidebar section and re-
        // posts a section-scoped notification (.cozyNewTask /
        // .cozyNewHabit / .cozyNewCountdown) that the matching composer
        // subscribes to. Keeping the resolution in RootView means Commands
        // doesn't need a binding back into the view hierarchy.
        CommandGroup(replacing: .newItem) {
            Button("New\u{2026}") {
                NotificationCenter.default.post(name: .cozyNewItem, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)
        }

        // UX LOW #103: ⌘L jumps first-responder to the inline quick-add field
        // when one is present (today: TaskInbox). We post a notification so
        // the field's owner can subscribe without Commands needing a binding
        // back into the view hierarchy.
        // TODO: TaskViews subscriber side. The TaskInbox quick-add bar should
        // `.onReceive(NotificationCenter.default.publisher(for: .cozyFocusQuickAdd))`
        // and move focus to its FocusState. Until then the menu item is still
        // visible so the keybinding is discoverable in the cheatsheet.
        CommandMenu("Edit Extras") {
            Button("Focus Quick-Add") {
                NotificationCenter.default.post(name: .cozyFocusQuickAdd, object: nil)
            }
            .keyboardShortcut("l", modifiers: .command)
        }

        // UX HIGH #80: ⌘? Help menu cheatsheet (replaces the default
        // "CozyTime Help" item that linked nowhere).
        KeyboardShortcutsCommand()
    }

    private func scheduleFocusCompletion() {
        guard let startDate = timerStore.snapshot.startDate else { return }
        let draft = NotificationPlanner.focusCompletion(
            sessionID: UUID(),
            taskTitle: timerStore.activeTaskTitle,
            startDate: startDate,
            duration: timerStore.snapshot.duration,
            accumulatedPause: timerStore.snapshot.accumulatedPause
        )
        Task {
            await notifications.cancelFocusNotifications()
            await notifications.schedule(draft)
        }
    }

    private var rememberedFocusMinutes: Int {
        FocusDefaults.rememberedFocusMinutes()
    }
}
