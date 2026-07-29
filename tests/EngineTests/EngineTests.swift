import XCTest

/// The single test seam: key events into the Engine, real Candidates and
/// Commits out, against a scratch Rime Directory seeded from the vendored
/// baseline. All Engine tests share the process-wide `TestEngine.shared`.
final class EngineTests: XCTestCase {
    /// Ticket 07 acceptance: type 'nihao', '你好' appears in Candidates;
    /// selecting it Commits '你好'.
    func testNihaoCandidatesAndCommit() throws {
        let engine = try TestEngine.shared.get()
        XCTAssertTrue(engine.startSession())

        for character in "nihao" {
            let key = try XCTUnwrap(Engine.Key(character: character))
            XCTAssertTrue(engine.processKey(key))
        }

        let input = engine.input
        XCTAssertFalse(input.composition.isEmpty)
        let index = try XCTUnwrap(
            input.candidates.firstIndex(where: { $0.text == "你好" }),
            "expected 你好 among candidates, got \(input.candidates.map(\.text))"
        )

        XCTAssertTrue(engine.selectCandidate(at: index))
        XCTAssertEqual(engine.takeCommit(), "你好")

        engine.endSession()
    }
}
