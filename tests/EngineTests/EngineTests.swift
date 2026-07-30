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
        defer { engine.endSession() }

        try type("nihao", into: engine)

        let input = engine.input
        XCTAssertFalse(input.composition.isEmpty)
        let index = try XCTUnwrap(
            input.candidates.firstIndex(where: { $0.text == "你好" }),
            "expected 你好 among candidates, got \(input.candidates.map(\.text))"
        )

        XCTAssertTrue(engine.selectCandidate(at: index))
        XCTAssertEqual(engine.takeCommit(), "你好")
    }

    /// The keyboard's backspace forwards to the Engine while a Composition is
    /// in progress; the Engine shortens it by one key.
    func testBackspaceEditsComposition() throws {
        let engine = try TestEngine.shared.get()
        XCTAssertTrue(engine.startSession())
        defer { engine.endSession() }

        try type("ni", into: engine)
        let before = engine.input.composition
        try type("h", into: engine)
        XCTAssertNotEqual(engine.input.composition, before)

        XCTAssertTrue(engine.processKey(.backspace))
        XCTAssertEqual(engine.input.composition, before)
    }

    /// Space on an open Candidate menu commits the first Candidate — the
    /// keyboard's space key just forwards and drains the Commit.
    func testSpaceCommitsFirstCandidate() throws {
        let engine = try TestEngine.shared.get()
        XCTAssertTrue(engine.startSession())
        defer { engine.endSession() }

        try type("nihao", into: engine)
        let first = try XCTUnwrap(engine.input.candidates.first?.text)

        XCTAssertTrue(engine.processKey(.space))
        XCTAssertEqual(engine.takeCommit(), first)
        XCTAssertTrue(engine.input.composition.isEmpty)
    }

    /// Return commits the raw input as-is (default Rime binding) — the
    /// keyboard's return key needs no Engine method of its own.
    func testReturnCommitsRawInput() throws {
        let engine = try TestEngine.shared.get()
        XCTAssertTrue(engine.startSession())
        defer { engine.endSession() }

        try type("ni", into: engine)

        XCTAssertTrue(engine.processKey(.return))
        XCTAssertEqual(engine.takeCommit(), "ni")
    }

    /// The keyboard clears a stale Composition when presented for a new text
    /// field — nothing Commits.
    func testClearComposition() throws {
        let engine = try TestEngine.shared.get()
        XCTAssertTrue(engine.startSession())
        defer { engine.endSession() }

        try type("ni", into: engine)
        XCTAssertFalse(engine.input.composition.isEmpty)

        engine.clearComposition()
        XCTAssertTrue(engine.input.composition.isEmpty)
        XCTAssertNil(engine.takeCommit())
    }

    /// Types ASCII text into the Engine, one key per character.
    private func type(_ text: String, into engine: Engine) throws {
        for character in text {
            engine.processKey(try XCTUnwrap(Engine.Key(character: character)))
        }
    }
}
