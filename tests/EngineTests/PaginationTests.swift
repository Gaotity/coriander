import XCTest

/// Ticket 13: Candidate pagination and schema keybindings at the Engine
/// seam. Behavior below was first measured by probes against the vendored
/// baseline (ENG-59): page_size is 5, `=`/`.` page down and `-`/`,` page up
/// via the schema's key_binder, digits select by index on the current page,
/// space commits the first Candidate of the current page, and the baseline
/// yields no Candidate comments until `zh_hans/tips: all` is patched in.
final class PaginationTests: XCTestCase {
    /// The menu exposes page state: 'yi' has far more than one page of
    /// Candidates, so the first read sits on page 0 with a next page.
    func testMenuExposesPageState() throws {
        let engine = try TestEngine.shared.get()
        XCTAssertTrue(engine.startSession())
        defer { engine.endSession() }

        try type("yi", into: engine)
        let state = engine.input
        XCTAssertEqual(state.pageNo, 0)
        XCTAssertTrue(state.hasNextPage)
        XCTAssertEqual(state.candidates.count, 5)
    }

    /// nextPage/previousPage walk the Candidate list; the pages are
    /// disjoint, so page 2+ Candidates are reachable.
    func testPageTurnReachesLaterCandidates() throws {
        let engine = try TestEngine.shared.get()
        XCTAssertTrue(engine.startSession())
        defer { engine.endSession() }

        try type("yi", into: engine)
        let page0 = engine.input.candidates.map(\.text)

        XCTAssertTrue(engine.nextPage())
        XCTAssertEqual(engine.input.pageNo, 1)
        let page1 = engine.input.candidates.map(\.text)
        XCTAssertEqual(page1.count, 5)
        XCTAssertTrue(page1.allSatisfy { !page0.contains($0) },
                      "page 1 repeats page 0: \(page1)")

        XCTAssertTrue(engine.previousPage())
        XCTAssertEqual(engine.input.pageNo, 0)
        XCTAssertEqual(engine.input.candidates.map(\.text), page0)
    }

    /// '/sz' has exactly six Candidates (two pages; the second holds one) —
    /// punct Candidates never enter the User Dictionary, so this is stable.
    /// Paging past the last page is refused and keeps the page in place.
    func testLastPageRefusesFurtherPaging() throws {
        let engine = try TestEngine.shared.get()
        XCTAssertTrue(engine.startSession())
        defer { engine.endSession() }

        try type("/sz", into: engine)
        XCTAssertTrue(engine.input.hasNextPage)

        XCTAssertTrue(engine.nextPage())
        XCTAssertEqual(engine.input.pageNo, 1)
        XCTAssertEqual(engine.input.candidates.map(\.text), ["⚅"])
        XCTAssertFalse(engine.input.hasNextPage)

        XCTAssertFalse(engine.nextPage(), "already on the last page")
        XCTAssertEqual(engine.input.pageNo, 1)
        XCTAssertEqual(engine.input.candidates.map(\.text), ["⚅"])
    }

    /// Symmetric boundary: page 0 refuses to page backward.
    func testFirstPageRefusesBackwardPaging() throws {
        let engine = try TestEngine.shared.get()
        XCTAssertTrue(engine.startSession())
        defer { engine.endSession() }

        try type("/sz", into: engine)
        let page0 = engine.input.candidates.map(\.text)
        XCTAssertFalse(engine.previousPage(), "already on the first page")
        XCTAssertEqual(engine.input.candidates.map(\.text), page0)
    }

    /// Without a Candidate menu there is nothing to page.
    func testPagingWithoutMenuIsRefused() throws {
        let engine = try TestEngine.shared.get()
        XCTAssertTrue(engine.startSession())
        defer { engine.endSession() }

        XCTAssertFalse(engine.nextPage())
        XCTAssertFalse(engine.previousPage())
        XCTAssertEqual(engine.input.pageNo, 0)
        XCTAssertFalse(engine.input.hasNextPage)
    }

    /// Acceptance: pagination state resets on a new Composition — both when
    /// the Composition keeps changing and when a Commit starts a fresh one.
    func testPageResetsOnNewComposition() throws {
        let engine = try TestEngine.shared.get()
        XCTAssertTrue(engine.startSession())
        defer { engine.endSession() }

        try type("yi", into: engine)
        XCTAssertTrue(engine.nextPage())
        try type("h", into: engine)
        XCTAssertEqual(engine.input.pageNo, 0, "editing the Composition repages")

        XCTAssertTrue(engine.nextPage())
        XCTAssertTrue(engine.processKey(.space))
        XCTAssertNotNil(engine.takeCommit())
        try type("yi", into: engine)
        XCTAssertEqual(engine.input.pageNo, 0, "a fresh Composition starts on page 0")
    }

    /// Schema keybinding, paged: space commits the first Candidate of the
    /// CURRENT page (probed), so the bar and the binding stay in sync.
    func testSpaceCommitsFirstCandidateOfCurrentPage() throws {
        let engine = try TestEngine.shared.get()
        XCTAssertTrue(engine.startSession())
        defer { engine.endSession() }

        try type("yi", into: engine)
        XCTAssertTrue(engine.nextPage())
        let first = try XCTUnwrap(engine.input.candidates.first?.text)

        XCTAssertTrue(engine.processKey(.space))
        XCTAssertEqual(engine.takeCommit(), first)
    }

    /// Schema keybinding: digits select by index on the current page
    /// (probed: the selector consumes even an out-of-range digit without a
    /// Commit; with no Composition the Session declines the key, so the
    /// keyboard types the digit literally).
    func testDigitSelectsCandidateByIndex() throws {
        let engine = try TestEngine.shared.get()
        XCTAssertTrue(engine.startSession())
        defer { engine.endSession() }

        try type("nihao", into: engine)
        let second = engine.input.candidates[1].text
        XCTAssertTrue(engine.processKey(Engine.Key(character: "2")!))
        XCTAssertEqual(engine.takeCommit(), second)

        try type("nihao", into: engine)
        XCTAssertTrue(engine.processKey(Engine.Key(character: "7")!),
                      "the selector swallows out-of-range digits")
        XCTAssertNil(engine.takeCommit())
        engine.clearComposition()

        XCTAssertFalse(engine.processKey(Engine.Key(character: "2")!))
    }

    /// Digits address the visible page, like space does.
    func testDigitSelectsOnCurrentPage() throws {
        let engine = try TestEngine.shared.get()
        XCTAssertTrue(engine.startSession())
        defer { engine.endSession() }

        try type("yi", into: engine)
        XCTAssertTrue(engine.nextPage())
        let second = engine.input.candidates[1].text
        XCTAssertTrue(engine.processKey(Engine.Key(character: "2")!))
        XCTAssertEqual(engine.takeCommit(), second)
    }

    /// The schema's own paging bindings ('='/'.' down, '-'/',' up — the
    /// baseline's key_binder) turn the same pages as nextPage/previousPage.
    func testSchemaBoundPagingKeys() throws {
        let engine = try TestEngine.shared.get()
        XCTAssertTrue(engine.startSession())
        defer { engine.endSession() }

        try type("yi", into: engine)
        let page0 = engine.input.candidates.map(\.text)

        XCTAssertTrue(engine.processKey(Engine.Key(character: "=")!))
        XCTAssertEqual(engine.input.pageNo, 1)
        XCTAssertTrue(engine.processKey(Engine.Key(character: ".")!))
        XCTAssertEqual(engine.input.pageNo, 2)
        XCTAssertTrue(engine.processKey(Engine.Key(character: "-")!))
        XCTAssertEqual(engine.input.pageNo, 1)
        XCTAssertTrue(engine.processKey(Engine.Key(character: ",")!))
        XCTAssertEqual(engine.input.pageNo, 0)
        XCTAssertEqual(engine.input.candidates.map(\.text), page0)
    }

    /// Selection taps address the current page as well.
    func testSelectCandidateOnCurrentPage() throws {
        let engine = try TestEngine.shared.get()
        XCTAssertTrue(engine.startSession())
        defer { engine.endSession() }

        try type("yi", into: engine)
        XCTAssertTrue(engine.nextPage())
        let first = try XCTUnwrap(engine.input.candidates.first?.text)
        XCTAssertTrue(engine.selectCandidate(at: 0))
        XCTAssertEqual(engine.takeCommit(), first)
    }

    /// Candidate comments reach the Engine (spec user story 4). The
    /// baseline emits none (probed); patching `zh_hans/tips: all` into
    /// luna_pinyin_simp — whose zh_hans switch is on by default — makes the
    /// simplifier annotate converted Candidates with their originals.
    func testCandidateCommentsFlowThrough() throws {
        let engine = try TestEngine.shared.get()
        let custom = TestEngine.directory.user
            .appendingPathComponent("luna_pinyin_simp.custom.yaml")
        try "patch:\n  zh_hans/tips: all\n".write(to: custom, atomically: true, encoding: .utf8)
        try engine.deploy()
        defer {
            try? FileManager.default.removeItem(at: custom)
            try? engine.deploy()
        }

        XCTAssertTrue(engine.startSession())
        defer {
            engine.selectSchema("luna_pinyin")
            engine.endSession()
        }
        XCTAssertTrue(engine.selectSchema("luna_pinyin_simp"))
        try type("zhongguo", into: engine)

        let candidates = engine.input.candidates
        let converted = try XCTUnwrap(candidates.first(where: { $0.text == "中国" }),
                                      "got \(candidates)")
        XCTAssertEqual(converted.comment, "〔中國〕")
        // Unconverted Candidates (identical in both scripts) carry no comment.
        let plain = try XCTUnwrap(candidates.first(where: { $0.text == "忠果" }),
                                  "got \(candidates)")
        XCTAssertNil(plain.comment)
    }

    /// Types ASCII text into the Engine, one key per character.
    private func type(_ text: String, into engine: Engine) throws {
        for character in text {
            engine.processKey(try XCTUnwrap(Engine.Key(character: character)))
        }
    }
}
