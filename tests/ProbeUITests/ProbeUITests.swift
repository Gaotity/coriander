import XCTest

/// PROBE16: throwaway UI probes (not committed). `testProbeEnable` enables
/// the Coriander keyboard in Settings; the presentations themselves are
/// driven manually (KeyboardLastUsed + orientation-locked builds) because
/// XCUI keyboard switching and device rotation are unreliable on the iOS
/// 26 simulator. `testProbeFloating` pinches the already-active Coriander
/// keyboard to trigger the iPad floating presentation. Geometry data goes
/// to the App Group's probe16.log; screenshots are taken externally.
final class ProbeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = true
    }

    func testProbeEnable() throws {
        enableCorianderKeyboard()
        print("PROBE16-ENABLE-DONE")
    }

    func testProbeFloating() throws {
        let app = XCUIApplication()
        app.launch()
        _ = app.keyboards.element.waitForExistence(timeout: 40)
        print("PROBE16 coriander-up=\(app.buttons["方案"].waitForExistence(timeout: 20))")
        // Rotate to landscape and hold for the external screenshot.
        XCUIDevice.shared.orientation = .landscapeLeft
        print("PROBE16-LANDSCAPE-READY")
        sleep(25)
        XCUIDevice.shared.orientation = .portrait
        sleep(5)
        print("PROBE16 docked buttons="
            + app.buttons.allElementsBoundByIndex.map(\.label).joined(separator: "|"))
        // The iPad keyboard's bottom-right chevron opens the dock/float
        // menu on long press; fall back to a pinch on the keyboard area.
        var floated = false
        for label in ["Dismiss keyboard", "Hide keyboard", "chevron.down", "Keyboard Options"] {
            let chevron = app.buttons[label].firstMatch
            if chevron.exists, chevron.isHittable {
                chevron.press(forDuration: 1.5)
                sleep(1)
                let floating = app.menuItems["Floating"].firstMatch
                if floating.waitForExistence(timeout: 3) {
                    floating.tap()
                    floated = true
                }
                print("PROBE16 chevron \(label) floated=\(floated) menuItems="
                    + app.menuItems.allElementsBoundByIndex.map(\.label).joined(separator: "|"))
                break
            }
        }
        if !floated {
            let pinchTarget = app.keyboards.element.exists ? app.keyboards.element : app.buttons["空格"]
            pinchTarget.pinch(withScale: 0.1, velocity: -3)
        }
        print("PROBE16-FLOATING-READY")
        sleep(30)
        print("PROBE16-DONE")
    }

    private func enableCorianderKeyboard() {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        settings.launch()
        sleep(2)
        // Settings restores its last pane: walk back to the root list.
        let rootMarker = settings.staticTexts["General"].firstMatch
        for _ in 0 ..< 6 where !rootMarker.exists {
            let back = settings.navigationBars.buttons.element(boundBy: 0)
            guard back.exists, back.isHittable else { break }
            back.tap()
            sleep(1)
        }

        /// Taps a row by its visible text, scrolling the list until the
        /// row is hittable (Settings rows sit below the fold). Matches
        /// cells via their contained label so nav-bar titles (whose text
        /// can equal a row's) are not tapped by mistake.
        func tapRow(_ label: String) -> Bool {
            let cell = settings.cells.containing(.staticText, identifier: label).firstMatch
            for _ in 0 ..< 8 {
                if cell.exists, cell.isHittable {
                    cell.tap()
                    sleep(1)
                    return true
                }
                settings.swipeUp()
                sleep(1)
            }
            print("PROBE16 tapRow failed: \(label); visible texts="
                + settings.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: "|"))
            return false
        }

        guard tapRow("General"), tapRow("Keyboard") else { return }
        guard tapRow("Keyboards") else { return }
        // Already enabled by an earlier run?
        if settings.staticTexts["Coriander"].firstMatch.waitForExistence(timeout: 3) {
            print("PROBE16 settings: already enabled")
            settings.terminate()
            return
        }
        guard tapRow("Add New Keyboard…") || tapRow("Add New Keyboard...")
            || tapButton("Add New Keyboard") else { return }
        _ = tapRow("Coriander")
        print("PROBE16 settings: enable flow done")
        settings.terminate()
    }

    private func tapButton(_ label: String) -> Bool {
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        let button = settings.buttons[label].firstMatch
        guard button.waitForExistence(timeout: 3), button.isHittable else { return false }
        button.tap()
        sleep(1)
        return true
    }
}
