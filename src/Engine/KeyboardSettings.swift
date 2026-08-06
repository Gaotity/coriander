import Foundation

/// The settings bridge (ticket 16): UI-layer settings carried from the
/// Container App to the Keyboard Extension through the App Group's
/// `UserDefaults`, per the spec's Settings decision — Rime-layer settings
/// (schema enable/order) travel via the Config Folder + Deploy instead.
/// The Container App writes; the keyboard re-reads on each presentation,
/// so a change applies without a Session restart. The same bridge carries
/// the User Dictionary generation (ENG-69), which the keyboard answers
/// WITH a Session restart. Reading App Group defaults needs no Full Access.
struct KeyboardSettings {
    private enum Key {
        static let showsKeyPopup = "keyboard.showsKeyPopup"
        static let keyboardHeight = "keyboard.keyboardHeight"
        static let userDictionaryGeneration = "keyboard.userDictionaryGeneration"
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

    /// Content generation of the User Dictionary (ENG-69): the Container
    /// App's Clear and Restore bump it AFTER the file/levers work succeeds;
    /// the keyboard snapshots it per Session and restarts the Session when
    /// it changes, so a Clear takes effect on the keyboard's next
    /// presentation instead of whenever iOS reaps the warm process. Zero
    /// when unset — both sides start at zero, so upgrading users see no
    /// spurious restart.
    var userDictionaryGeneration: Int {
        get { defaults.integer(forKey: Key.userDictionaryGeneration) }
        nonmutating set { defaults.set(newValue, forKey: Key.userDictionaryGeneration) }
    }
}
