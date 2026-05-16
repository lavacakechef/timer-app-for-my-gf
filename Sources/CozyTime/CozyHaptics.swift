import AppKit

enum CozyHaptics {
    enum Pattern { case completion, milestone, reward }

    /// Fires a soft haptic on Force Touch trackpads. No-op on non-haptic
    /// devices. Gated on the `cozyHapticsEnabled` AppStorage flag so users
    /// can disable in Settings (the toggle UI lives in Settings views;
    /// here we just read the default value if no flag is stored).
    @MainActor
    static func perform(_ pattern: Pattern) {
        let enabled = UserDefaults.standard.object(forKey: "cozyHapticsEnabled") as? Bool ?? true
        guard enabled else { return }
        let performer = NSHapticFeedbackManager.defaultPerformer
        switch pattern {
        case .completion: performer.perform(.levelChange, performanceTime: .now)
        case .milestone:  performer.perform(.alignment, performanceTime: .now)
        case .reward:     performer.perform(.generic, performanceTime: .now)
        }
    }
}
