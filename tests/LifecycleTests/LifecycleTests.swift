import XCTest

/// Verifies that librime 1.17 tolerates a finalize → re-initialize cycle
/// within one process — the fact that lets the Container App run each Deploy
/// on a short-lived Engine and release the User Dictionary immediately.
/// Runs in its own test target because the probe finalizes librime, which
/// must not disturb the shared Engine of the main suite.
final class LifecycleTests: XCTestCase {
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
