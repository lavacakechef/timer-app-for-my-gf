import CozyCore
import SwiftUI

struct CozyCommands: Commands {
    let timerStore: FocusTimerStore
    let notifications: NotificationService

    var body: some Commands {
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
