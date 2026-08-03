import XCTest

/// The onboarding gate (ticket 18): the unset default, a completion round
/// trip, and explicit-false persistence over a throwaway suite. The
/// app-launch half (fresh install shows the flow, the next launch skips it)
/// is covered by simulator smoke, not here.
final class OnboardingStateTests: XCTestCase {
    private let suiteName = "com.gaotity.coriander.tests.onboarding-state"

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

    func testHasCompletedOnboardingDefaultsToFalseWhenUnset() {
        XCTAssertFalse(OnboardingState(defaults: makeDefaults()).hasCompletedOnboarding)
    }

    func testHasCompletedOnboardingTrueRoundTrips() {
        OnboardingState(defaults: makeDefaults()).hasCompletedOnboarding = true
        XCTAssertTrue(OnboardingState(defaults: makeDefaults()).hasCompletedOnboarding)
    }

    func testHasCompletedOnboardingExplicitFalsePersists() {
        OnboardingState(defaults: makeDefaults()).hasCompletedOnboarding = false
        XCTAssertFalse(OnboardingState(defaults: makeDefaults()).hasCompletedOnboarding)
    }
}
