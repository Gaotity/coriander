import XCTest

/// The settings bridge wrapper (ticket 16): the unset default, a write
/// round trip, and explicit-true persistence over a throwaway suite. The
/// cross-process half (the Container App writes, the keyboard reads the
/// same App Group suite) is covered by simulator/device smoke, not here.
final class KeyboardSettingsTests: XCTestCase {
    private let suiteName = "com.gaotity.coriander.tests.keyboard-settings"

    override func setUp() {
        super.setUp()
        makeDefaults().removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        makeDefaults().removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: suiteName)!
    }

    func testKeyPopupDefaultsToOnWhenUnset() {
        XCTAssertTrue(KeyboardSettings(defaults: makeDefaults()).showsKeyPopup)
    }

    func testKeyPopupOffRoundTrips() {
        KeyboardSettings(defaults: makeDefaults()).showsKeyPopup = false
        XCTAssertFalse(KeyboardSettings(defaults: makeDefaults()).showsKeyPopup)
    }

    func testKeyPopupExplicitOnPersists() {
        KeyboardSettings(defaults: makeDefaults()).showsKeyPopup = true
        XCTAssertTrue(KeyboardSettings(defaults: makeDefaults()).showsKeyPopup)
    }

    func testKeyboardHeightDefaultsToStandardWhenUnset() {
        XCTAssertEqual(KeyboardSettings(defaults: makeDefaults()).keyboardHeight, .standard)
    }

    func testKeyboardHeightCompactRoundTrips() {
        KeyboardSettings(defaults: makeDefaults()).keyboardHeight = .compact
        XCTAssertEqual(KeyboardSettings(defaults: makeDefaults()).keyboardHeight, .compact)
    }

    func testKeyboardHeightExplicitStandardPersists() {
        KeyboardSettings(defaults: makeDefaults()).keyboardHeight = .standard
        XCTAssertEqual(KeyboardSettings(defaults: makeDefaults()).keyboardHeight, .standard)
    }
}
