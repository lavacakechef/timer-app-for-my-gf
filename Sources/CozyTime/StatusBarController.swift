// DEPRECATED: replaced by MenuBarExtra in CozyTimeApp.swift (macOS 15).
// This file is kept for reference / rollback only. It is no longer
// instantiated by the app and will be deleted after the next release
// cycle confirms MenuBarExtra is stable in production.
import AppKit
import Combine
import CozyCore
import SwiftUI

@MainActor
final class StatusBarController: NSObject, ObservableObject {
    private let dataStore: AppDataStore
    private let timerStore: FocusTimerStore
    private let notifications: NotificationService
    private let popover = NSPopover()
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()

    init(
        dataStore: AppDataStore,
        timerStore: FocusTimerStore,
        notifications: NotificationService
    ) {
        self.dataStore = dataStore
        self.timerStore = timerStore
        self.notifications = notifications
        super.init()

        popover.behavior = .transient
        popover.animates = false

        timerStore.$snapshot
            .combineLatest(timerStore.$currentDate, timerStore.$activeTaskTitle)
            .sink { [weak self] _ in
                self?.updateButton()
            }
            .store(in: &cancellables)
    }

    func setVisible(_ isVisible: Bool) {
        if isVisible {
            installIfNeeded()
            updateButton()
        } else {
            remove()
        }
    }

    private func installIfNeeded() {
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem = item

        if let button = item.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.imagePosition = .imageLeading
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            if let image = NSImage(named: "menubar-paw-timer") ?? NSImage(named: "menubar-cloud-clock") {
                image.isTemplate = true
                button.image = image
            }
        }
    }

    private func remove() {
        if let statusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
        }
        statusItem = nil
        popover.close()
    }

    private func updateButton() {
        guard let button = statusItem?.button else { return }
        let hasTimerStatus = timerStore.isActive || timerStore.needsCompletionReview
        // Compact title — just the timer (MM:SS), no task name. The task name
        // goes to the tooltip. Previous implementation included the task name
        // ("Sleep Focus 88:24") which on a 13" MBA with a notch + many system
        // items would push CozyTime out of the visible menu bar entirely.
        // macOS Sequoia silently hides overflow status items beyond the notch.
        let title: String
        if timerStore.needsCompletionReview {
            title = " save"
        } else if timerStore.isActive {
            title = " \(timerStore.menuBarTitle(at: timerStore.currentDate))"
        } else {
            title = ""
        }
        statusItem?.length = hasTimerStatus
            ? min(120, max(76, CGFloat(title.count * 7 + 30)))
            : NSStatusItem.squareLength
        button.title = title
        button.toolTip = timerStore.isActive
            ? "CozyTime: \(timerStore.activeTaskTitle), \(timerStore.menuBarTitle(at: timerStore.currentDate)) remaining"
            : timerStore.needsCompletionReview
            ? "CozyTime: \(timerStore.activeTaskTitle) is ready to save"
            : "CozyTime"
        button.setAccessibilityLabel(
            hasTimerStatus
                ? "CozyTime: \(timerStore.activeTaskTitle), \(timerStore.menuBarTitle(at: timerStore.currentDate))"
                : "CozyTime"
        )
    }

    private var shortMenuBarTaskTitle: String {
        let title = timerStore.activeTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return "Focus" }
        if title.count <= 14 { return title }
        return "\(title.prefix(13))..."
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        if let event = NSApp.currentEvent, event.type == .rightMouseUp {
            showContextMenu(for: sender, event: event)
            return
        }

        if popover.isShown {
            popover.close()
            return
        }

        let rootView = MenuBarPanelView()
            .environmentObject(dataStore)
            .environmentObject(timerStore)
            .environmentObject(notifications)
        popover.contentViewController = NSHostingController(rootView: rootView)
        let visibleHeight = sender.window?.screen?.visibleFrame.height ?? NSScreen.main?.visibleFrame.height ?? 720
        popover.contentSize = NSSize(width: 360, height: min(640, max(420, visibleHeight - 80)))
        let anchor = NSRect(
            x: sender.bounds.midX,
            y: sender.bounds.minY,
            width: 1,
            height: sender.bounds.height
        )
        popover.show(relativeTo: anchor, of: sender, preferredEdge: .minY)
    }

    private func showContextMenu(for sender: NSStatusBarButton, event: NSEvent) {
        let menu = NSMenu()
        let primaryTitle = timerStore.isRunning
            ? "Pause Timer"
            : timerStore.isPaused
            ? "Resume Timer"
            : timerStore.needsCompletionReview
            ? "Review Focus Reward"
            : "Start \(CozyFormatters.durationLabel(TimeInterval(rememberedFocusMinutes * 60))) Focus"
        let primaryItem = NSMenuItem(title: primaryTitle, action: #selector(toggleTimerFromMenu), keyEquivalent: "")
        primaryItem.target = self
        menu.addItem(primaryItem)

        if timerStore.needsCompletionReview {
            let saveItem = NSMenuItem(title: "Open Focus Review", action: #selector(saveFinishedTimerFromMenu), keyEquivalent: "")
            saveItem.target = self
            menu.addItem(saveItem)
        }

        let openItem = NSMenuItem(title: "Open CozyTime", action: #selector(openAppFromMenu), keyEquivalent: "")
        openItem.target = self
        menu.addItem(openItem)

        menu.addItem(.separator())
        let quitItem = NSMenuItem(title: "Quit CozyTime", action: #selector(quitAppFromMenu), keyEquivalent: "")
        quitItem.target = self
        menu.addItem(quitItem)

        NSMenu.popUpContextMenu(menu, with: event, for: sender)
    }

    @objc private func toggleTimerFromMenu() {
        if timerStore.isRunning {
            timerStore.pause()
            Task { await notifications.cancelFocusNotifications() }
        } else if timerStore.isPaused {
            timerStore.resume()
            scheduleFocusCompletion()
        } else if timerStore.needsCompletionReview {
            openSectionFromMenu(.focus)
        } else if timerStore.canStartNewSession {
            UserDefaults.standard.set(FocusBoost.default.id, forKey: "focus.activeBoostID")
            // Use the user's last-picked duration (persisted on every Focus
            // start) instead of a hardcoded 25 minutes. Mirrors the parallel
            // path in MenuBarPanelView.startMenuBarFocus.
            timerStore.startRememberedQuickFocus()
            scheduleFocusCompletion()
        }
    }

    @objc private func openAppFromMenu() {
        CozyAppDelegate.openMainWindowIfNeeded()
    }

    @objc private func saveFinishedTimerFromMenu() {
        openSectionFromMenu(.focus)
    }

    @objc private func quitAppFromMenu() {
        NSApp.terminate(nil)
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

    private func completeFocusFromMenu() {
        guard timerStore.isActive || timerStore.needsCompletionReview else { return }
        let now = Date()
        let boost = FocusRewardResolver.activeBoostFromDefaults()
        let reward = FocusRewardResolver.resolve(
            snapshot: timerStore.snapshot,
            taskTitle: timerStore.activeTaskTitle,
            boost: boost,
            existingRewards: dataStore.rewards,
            lifetimeSessionCount: dataStore.focusSessions.count,
            now: now
        )
        timerStore.complete(at: now)
        Task { await notifications.cancelFocusNotifications() }
        dataStore.addFocusSession(reward.session)
        if let item = reward.adventureRoll?.reward {
            dataStore.unlockReward(item)
        }
        if reward.shouldCompleteTask, let taskID = timerStore.activeTaskID {
            dataStore.completeTask(id: taskID, at: now)
        }
        CozyFeedback.play(reward.isRewardEligible ? .reward : .complete)
        // TODO(UX-88): personalize completion microcopy with mascotName
        // (status-bar tooltip strings here aren't mascot-voice today).
        CozyHaptics.perform(reward.isRewardEligible ? .reward : .completion)
        timerStore.reset()
        UserDefaults.standard.set("", forKey: "focus.activeBoostID")
        updateButton()
    }

    private func openSectionFromMenu(_ section: AppSection) {
        CozyAppDelegate.openSection(section)
    }

    private var rememberedFocusMinutes: Int {
        FocusDefaults.rememberedFocusMinutes()
    }
}
