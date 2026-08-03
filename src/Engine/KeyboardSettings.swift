import Foundation

/// The settings bridge (ticket 16): UI-layer settings carried from the
/// Container App to the Keyboard Extension through the App Group's
/// `UserDefaults`, per the spec's Settings decision — Rime-layer settings
/// (schema enable/order) travel via the Config Folder + Deploy instead.
/// The Container App writes; the keyboard re-reads on each presentation,
/// so a change applies without a Session restart. Reading App Group
/// defaults needs no Full Access.
struct KeyboardSettings {
    private enum Key {
        static let showsKeyPopup = "keyboard.showsKeyPopup"
        static let keyboardHeight = "keyboard.keyboardHeight"
    }

    /// The Layout choice for row height (ticket 17): standard matches the
    /// iOS-native geometry; compact shrinks the rows for more screen room.
    enum KeyboardHeight: String {
        case standard
        case compact
    }

    private let defaults: UserDefaults

    /// `.standard` is the last-resort fallback for a missing group suite,
    /// degrading the bridge to per-process defaults instead of trapping.
    init(defaults: UserDefaults = UserDefaults(suiteName: RimeDirectory.groupID) ?? .standard) {
        self.defaults = defaults
    }

    /// Whether a pressed key shows its enlarged keycap popup. On when
    /// unset, matching the native keyboard.
    var showsKeyPopup: Bool {
        get { defaults.object(forKey: Key.showsKeyPopup) as? Bool ?? true }
        // Nonmutating: the struct only wraps a `UserDefaults` reference.
        nonmutating set { defaults.set(newValue, forKey: Key.showsKeyPopup) }
    }

    /// The chosen row height. Standard when unset.
    var keyboardHeight: KeyboardHeight {
        get { KeyboardHeight(rawValue: defaults.string(forKey: Key.keyboardHeight) ?? "") ?? .standard }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Key.keyboardHeight) }
    }
}
