import XCTest

/// Verifies that librime 1.17 tolerates a finalize → re-initialize cycle
/// within one process — the fact that lets the Container App run each Deploy
/// on a short-lived Engine and release the User Dictionary immediately.
/// Runs in its own test target because the probe finalizes librime, which
/// must not disturb the shared Engine of the main suite.
final class LifecycleTests: XCTestCase {
    /// The in-process half of the single-writer rule: a second live Engine
    /// in one process is rejected, and the slot frees on `shutdown()`.
    /// Cross-process, the User Dictionary's LevelDB lock arbitrates
    /// (ADR-0004); the handoff is covered by CorianderLifecycleTests'
    /// ReadOnlyTests.
    func testSecondLiveEngineIsRejected() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("coriander-lifecycle-single-writer", isDirectory: true)
        try? FileManager.default.removeItem(at: root)
        let directory = RimeDirectory(root: root)
        let baseline = Bundle(for: LifecycleTests.self).resourceURL!
            .appendingPathComponent("rime-baseline", isDirectory: true)
        try directory.seed(from: baseline)

        let first = try Engine(directory: directory)
        XCTAssertThrowsError(try Engine(directory: directory)) { error in
            guard case Engine.StartError.alreadyStarted = error else {
                return XCTFail("expected alreadyStarted, got \(error)")
            }
        }
        first.shutdown()

        let second = try Engine(directory: directory)
        second.shutdown()
    }

    func testFinalizeThenReinitialize() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("coriander-lifecycle-tests", isDirectory: true)
        try? FileManager.default.removeItem(at: root)
        let directory = RimeDirectory(root: root)
        let baseline = Bundle(for: LifecycleTests.self).resourceURL!
            .appendingPathComponent("rime-baseline", isDirectory: true)
        try directory.seed(from: baseline)

        let first = try Engine(directory: directory)
        try first.deploy()
        XCTAssertTrue(first.startSession())
        for character in "nihao" {
            first.processKey(try XCTUnwrap(Engine.Key(character: character)))
        }
        XCTAssertTrue(first.input.candidates.contains(where: { $0.text == "你好" }))
        first.shutdown()

        // The cycle under test: a new Engine on the same directory after a
        // finalized one — no fresh Deploy, existing artifacts must serve.
        let second = try Engine(directory: directory)
        XCTAssertTrue(second.startSession())
        for character in "nihao" {
            second.processKey(try XCTUnwrap(Engine.Key(character: character)))
        }
        XCTAssertTrue(second.input.candidates.contains(where: { $0.text == "你好" }))
        second.shutdown()
    }
}
