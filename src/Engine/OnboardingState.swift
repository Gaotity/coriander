import Foundation

/// The onboarding gate (ticket 18): the Container App shows its guided
/// first-launch flow once and records completion here, so the next launch
/// goes straight to the main screen. Stored in the App Group's
/// `UserDefaults` alongside the settings bridge (KeyboardSettings) — the
/// Keyboard Extension never reads it, but one suite keeps one storage
/// convention. Deleting the app clears the suite, so a reinstall onboards
/// again.
struct OnboardingState {
    private enum Key {
        static let hasCompletedOnboarding = "onboarding.hasCompleted"
    }

    private let defaults: UserDefaults

    /// A missing group suite degrades to per-process defaults — onboarding
    /// simply shows again next launch instead of trapping.
    init(defaults: UserDefaults = UserDefaults(suiteName: RimeDirectory.groupID) ?? .standard) {
        self.defaults = defaults
    }

    /// False when unset (fresh install).
    var hasCompletedOnboarding: Bool {
        get { defaults.bool(forKey: Key.hasCompletedOnboarding) }
        // Nonmutating: the struct only wraps a `UserDefaults` reference.
        nonmutating set { defaults.set(newValue, forKey: Key.hasCompletedOnboarding) }
    }
}
