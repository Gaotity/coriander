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

    /// A Deploy makes new configuration visible to the NEXT Session
    /// (ADR-0001: no hot swap). Proven with a page_size patch: baseline
    /// page_size is 5, the patch sets 9, cleanup restores 5.
    func testDeployNewSessionLoadsNewArtifacts() throws {
        let engine = try TestEngine.shared.get()

        // Control: before the patch, the page holds at most 5 Candidates.
        XCTAssertTrue(engine.startSession())
        try type("nihao", into: engine)
        XCTAssertLessThanOrEqual(engine.input.candidates.count, 5)
        engine.endSession()

        let custom = TestEngine.directory.user.appendingPathComponent("luna_pinyin.custom.yaml")
        try "patch:\n  menu/page_size: 9\n".write(to: custom, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: custom)
            try? engine.deploy()
        }
        try engine.deploy()

        XCTAssertTrue(engine.startSession())
        defer { engine.endSession() }
        try type("nihao", into: engine)
        XCTAssertGreaterThan(engine.input.candidates.count, 5)
    }

    /// Living documentation, not a desired behavior: librime TOLERATES a
    /// broken custom patch — the full Deploy succeeds (probed
    /// `deploy_schema` too), the patch is silently not applied, and typing
    /// is unaffected. Deploy therefore cannot validate user-edited config
    /// syntax; tickets 10/15 must handle that before Deploy.
    func testBrokenCustomPatchIsTolerated() throws {
        let engine = try TestEngine.shared.get()
        let custom = TestEngine.directory.user.appendingPathComponent("luna_pinyin.custom.yaml")
        try "patch: [unclosed\n".write(to: custom, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: custom)
            try? engine.deploy()
        }

        XCTAssertNoThrow(try engine.deploy())

        XCTAssertTrue(engine.startSession())
        defer { engine.endSession() }
        try type("nihao", into: engine)
        XCTAssertTrue(engine.input.candidates.contains(where: { $0.text == "你好" }))
    }

    /// A failed Deploy (broken schema source) is reported by name and leaves
    /// the last-good artifacts usable: typing keeps working.
    func testFailedDeployKeepsTypingIntact() throws {
        let engine = try TestEngine.shared.get()
        let schema = TestEngine.directory.shared.appendingPathComponent("luna_pinyin.schema.yaml")
        let backup = try Data(contentsOf: schema)
        try "garbage: [unclosed\n".write(to: schema, atomically: true, encoding: .utf8)
        defer {
            try? backup.write(to: schema)
            try? engine.deploy()
        }

        XCTAssertThrowsError(try engine.deploy()) { error in
            guard case Engine.DeployError.schemasFailed(let failed) = error else {
                return XCTFail("expected schemasFailed, got \(error)")
            }
            XCTAssertTrue(failed.contains("luna_pinyin.schema.yaml"))
        }

        XCTAssertTrue(engine.startSession())
        defer { engine.endSession() }
        try type("nihao", into: engine)
        XCTAssertTrue(engine.input.candidates.contains(where: { $0.text == "你好" }),
                      "typing broke after failed Deploy: \(engine.input.candidates.map(\.text))")
    }

    /// Types ASCII text into the Engine, one key per character.
    private func type(_ text: String, into engine: Engine) throws {
        for character in text {
            engine.processKey(try XCTUnwrap(Engine.Key(character: character)))
        }
    }
}
