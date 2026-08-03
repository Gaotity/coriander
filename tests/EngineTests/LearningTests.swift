import XCTest

/// librime's User Dictionary learning (ticket 14), probed then kept as
/// regression coverage. Findings: learning is automatic on Commit — a
/// committed phrase lands in `<user>/<schema>.userdb` (a LevelDB
/// directory) and outranks the table from the next Session; selecting an
/// existing Candidate ranks it up the same way; the only off switch is
/// configuration (`translator/enable_user_dict`), never a runtime toggle.
final class LearningTests: XCTestCase {
    /// Coining a word by picking its characters one at a time — the way a
    /// user actually coins one — persists it into the User Dictionary: the
    /// coined word then outranks the table's deterministic guess on the
    /// next Session. Strong oracle: the coined word is no table entry and
    /// is never the assembled guess, so without learning it cannot appear
    /// at all. (Committing the assembled guess unchanged would be a
    /// vacuous oracle — the guess comes out first either way.) Partial
    /// selections do not Commit; one Commit lands when the last segment is
    /// picked (probed).
    func testCoinedWordPersistsAndRanksUpAcrossSessions() throws {
        let engine = try TestEngine.shared.get()
        let input = "gouze"
        // 夠 for "gou", then 澤 for "ze": 夠澤 is in no table (checked
        // against the vendored baseline) and the deterministic guess for
        // this input is 夠則, so only the User Dictionary can offer 夠澤.
        let coined = "夠澤"

        try session(engine) {
            try type(input, into: engine)
            try select("夠", from: engine)
            XCTAssertNil(engine.takeCommit())
            try select("澤", from: engine)
            XCTAssertEqual(engine.takeCommit(), coined)
        }

        try session(engine) {
            try type(input, into: engine)
            let candidates = engine.input.candidates.map(\.text)
            XCTAssertEqual(candidates.first, coined,
                           "coined word did not rank first on the next Session: \(candidates)")
        }
    }

    /// Selecting a non-first Candidate ranks it up on later Sessions — the
    /// everyday learning path (the keyboard's candidate tap). Strong
    /// oracle: without learning the rank is deterministic and cannot move.
    func testSelectionRanksUpAcrossSessions() throws {
        let engine = try TestEngine.shared.get()
        let input = "shiyi"
        let rankBefore = 2
        var chosen = ""

        try session(engine) {
            try type(input, into: engine)
            let before = engine.input.candidates.map(\.text)
            guard before.count > rankBefore else {
                XCTFail("need > \(rankBefore) candidates for \(input), got \(before)")
                return
            }
            chosen = before[rankBefore]
            XCTAssertTrue(engine.selectCandidate(at: rankBefore))
            XCTAssertEqual(engine.takeCommit(), chosen)
        }

        try session(engine) {
            try type(input, into: engine)
            let after = engine.input.candidates.map(\.text)
            let rankAfter = try XCTUnwrap(after.firstIndex(of: chosen),
                                          "selection vanished on retype: \(after)")
            XCTAssertLessThan(rankAfter, rankBefore,
                              "selection did not rank up: after \(after)")
        }
    }

    /// librime's learning switch is configuration, not a runtime toggle:
    /// `translator/enable_user_dict: false` + Deploy turns it off. The
    /// keyboard cannot write that patch without Full Access, so read-only
    /// mode must lean on librime's write-failure degradation instead.
    func testLearningCanBeDisabledByConfig() throws {
        let engine = try TestEngine.shared.get()
        let custom = TestEngine.directory.user.appendingPathComponent("luna_pinyin.custom.yaml")
        try "patch:\n  translator/enable_user_dict: false\n"
            .write(to: custom, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: custom)
            try? engine.deploy()
        }
        try engine.deploy()

        let input = "tuzei"
        var before = ""
        try session(engine) {
            try type(input, into: engine)
            before = try XCTUnwrap(engine.input.candidates.first?.text)
            XCTAssertTrue(engine.processKey(.space))
            XCTAssertEqual(engine.takeCommit(), before)
        }

        try session(engine) {
            try type(input, into: engine)
            let after = engine.input.candidates.map(\.text)
            XCTAssertEqual(after.first, before,
                           "learning happened despite enable_user_dict: false: \(after)")
        }
    }

    /// Runs `body` inside one Session, ending it even when `body` throws —
    /// a leaked Session would fail every later `startSession()` in this
    /// process (one Session per Engine).
    private func session(_ engine: Engine, _ body: () throws -> Void) throws {
        XCTAssertTrue(engine.startSession())
        defer { engine.endSession() }
        try body()
    }

    private func type(_ text: String, into engine: Engine) throws {
        for character in text {
            engine.processKey(try XCTUnwrap(Engine.Key(character: character)))
        }
    }

    /// Selects the Candidate whose text is `text` — e.g. picking the first
    /// character of a coined word mid-Composition.
    private func select(_ text: String, from engine: Engine) throws {
        let index = try XCTUnwrap(
            engine.input.candidates.firstIndex(where: { $0.text == text }),
            "\(text) not among candidates: \(engine.input.candidates.map(\.text))")
        XCTAssertTrue(engine.selectCandidate(at: index))
    }
}
