import XCTest

/// Probes for the read-only Rime Directory (ticket 14): without Full Access
/// the Keyboard Extension cannot write the App Group container (ticket 01,
/// measured on device), so librime must run against a read-only Rime
/// Directory without crashing, with learning silently off. Runs in this
/// target because it needs its own Engine lifecycle on its own directory —
/// the EngineTests process holds its shared Engine forever.
final class ReadOnlyTests: XCTestCase {
    /// The writability probe backing the tiering: false on a chmodded
    /// directory, true again once writable.
    func testCanWriteUserTracksWritability() throws {
        let directory = try Self.makeDirectory("probe")
        try Self.deploy(directory)
        defer { Self.remove(directory) }

        XCTAssertTrue(directory.canWriteUser)
        Self.setWritable(directory, false)
        XCTAssertFalse(directory.canWriteUser)
        Self.setWritable(directory, true)
        XCTAssertTrue(directory.canWriteUser)
    }

    /// The read-only degradation probe (probed findings): a fully read-only
    /// Rime Directory still serves typing — librime logs userdb open
    /// failures and carries on with no User Dictionary and no crash — and
    /// learning is silently off: a selection does not rank up and not a
    /// single file changes. The chmod a-w stands in for the keyboard's
    /// sandbox denial without Full Access.
    func testReadOnlyDirectoryServesTypingAndPersistsNothing() throws {
        let directory = try Self.makeDirectory("readonly")
        try Self.deploy(directory)
        defer { Self.remove(directory) }

        // Control: learning works here while writable, so the read-only
        // half has something to lose.
        let engine = try Engine(directory: directory)
        defer { engine.shutdown() }
        XCTAssertTrue(engine.startSession())
        try Self.type("maleng", into: engine)
        let coined = try XCTUnwrap(engine.input.candidates.first?.text)
        XCTAssertTrue(engine.processKey(.space))
        XCTAssertEqual(engine.takeCommit(), coined)
        engine.endSession()
        engine.shutdown()

        let filesBefore = Self.snapshot(directory)
        Self.setWritable(directory, false)

        let readOnly = try Engine(directory: directory)
        defer { readOnly.shutdown() }
        XCTAssertTrue(readOnly.startSession(), "session failed on read-only directory")
        try Self.type("nihao", into: readOnly)
        XCTAssertTrue(readOnly.input.candidates.contains(where: { $0.text == "你好" }),
                      "typing broke on read-only directory: \(readOnly.input.candidates.map(\.text))")
        XCTAssertTrue(readOnly.processKey(.space))
        XCTAssertNotNil(readOnly.takeCommit())

        // A selection here is a learning attempt: it must not rank up.
        try Self.type("shiyi", into: readOnly)
        let candidatesBefore = readOnly.input.candidates.map(\.text)
        guard candidatesBefore.count > 2 else {
            XCTFail("need > 2 candidates for shiyi, got \(candidatesBefore)")
            return
        }
        let chosen = candidatesBefore[2]
        XCTAssertTrue(readOnly.selectCandidate(at: 2))
        XCTAssertEqual(readOnly.takeCommit(), chosen)
        readOnly.endSession()
        readOnly.shutdown()

        let verify = try Engine(directory: directory)
        defer { verify.shutdown() }
        XCTAssertTrue(verify.startSession())
        try Self.type("shiyi", into: verify)
        XCTAssertEqual(verify.input.candidates.map(\.text), candidatesBefore,
                       "selection ranked up on a read-only directory — learning is not off")
        verify.endSession()

        XCTAssertEqual(Self.snapshot(directory), filesBefore,
                       "files changed under a read-only directory")
    }

    /// Single-writer handoff: one Engine's learning survives its shutdown
    /// and is visible to the next Engine on the same directory — the
    /// Container App's short-lived Deploy Engines and the keyboard's
    /// long-lived one pass the User Dictionary between processes this way
    /// (ADR-0004). Strong oracle: the coined word is picked character by
    /// character, is no table entry, and is never the assembled guess, so
    /// only a persisted User Dictionary can offer it.
    func testLearningSurvivesEngineHandoff() throws {
        let directory = try Self.makeDirectory("handoff")
        try Self.deploy(directory)
        defer { Self.remove(directory) }

        let input = "nuotu"
        // 諾 for "nuo", then 吐 for "tu": 諾吐 is in no table (checked
        // against the vendored baseline), so only the User Dictionary can
        // offer it later.
        let coined = "諾吐"

        let first = try Engine(directory: directory)
        defer { first.shutdown() }
        XCTAssertTrue(first.startSession())
        try Self.type(input, into: first)
        try Self.select("諾", from: first)
        // Partial selections do not Commit; one Commit lands when the last
        // segment is picked (probed).
        XCTAssertNil(first.takeCommit())
        try Self.select("吐", from: first)
        XCTAssertEqual(first.takeCommit(), coined)
        first.endSession()
        first.shutdown()

        let second = try Engine(directory: directory)
        defer { second.shutdown() }
        XCTAssertTrue(second.startSession())
        defer { second.endSession() }
        try Self.type(input, into: second)
        let candidates = second.input.candidates.map(\.text)
        XCTAssertEqual(candidates.first, coined,
                       "learning did not survive the Engine handoff: \(candidates)")
    }

    // MARK: helpers

    private static func makeDirectory(_ name: String) throws -> RimeDirectory {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("coriander-readonly-tests/\(name)-\(UUID().uuidString)",
                                    isDirectory: true)
        let directory = RimeDirectory(root: root)
        let baseline = Bundle(for: ReadOnlyTests.self).resourceURL!
            .appendingPathComponent("rime-baseline", isDirectory: true)
        try directory.seed(from: baseline)
        return directory
    }

    /// A short-lived Engine that Deploys and shuts down — the Container
    /// App's pattern (ADR-0004).
    private static func deploy(_ directory: RimeDirectory) throws {
        let engine = try Engine(directory: directory)
        defer { engine.shutdown() }
        try engine.deploy()
    }

    private static func type(_ text: String, into engine: Engine) throws {
        for character in text {
            engine.processKey(try XCTUnwrap(Engine.Key(character: character)))
        }
    }

    /// Selects the Candidate whose text is `text` — picking one character
    /// of a coined word mid-Composition.
    private static func select(_ text: String, from engine: Engine) throws {
        let index = try XCTUnwrap(
            engine.input.candidates.firstIndex(where: { $0.text == text }),
            "\(text) not among candidates: \(engine.input.candidates.map(\.text))")
        XCTAssertTrue(engine.selectCandidate(at: index))
    }

    /// Path + mtime of every entry under the Rime Directory, sorted — the
    /// "nothing persisted" witness.
    private static func snapshot(_ directory: RimeDirectory) -> [String] {
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: directory.root.path) else { return [] }
        return enumerator.compactMap { entry -> String? in
            guard let path = entry as? String else { return nil }
            let full = directory.root.appendingPathComponent(path)
            let mtime = (try? fm.attributesOfItem(atPath: full.path))?[.modificationDate] as? Date
            return "\(path)@\(mtime?.timeIntervalSince1970 ?? -1)"
        }.sorted()
    }

    /// chmod a-w recursively (directories 0555, files 0444) and back.
    private static func setWritable(_ directory: RimeDirectory, _ writable: Bool) {
        let fm = FileManager.default
        let paths = [directory.root.path]
            + ((fm.enumerator(atPath: directory.root.path)?.allObjects as? [String]) ?? [])
                .map { directory.root.appendingPathComponent($0).path }
        for path in paths {
            var isDirectory: ObjCBool = false
            fm.fileExists(atPath: path, isDirectory: &isDirectory)
            try? fm.setAttributes(
                [.posixPermissions: writable
                    ? (isDirectory.boolValue ? 0o755 : 0o644)
                    : (isDirectory.boolValue ? 0o555 : 0o444)],
                ofItemAtPath: path)
        }
    }

    /// Back to writable, then remove the scratch directory.
    private static func remove(_ directory: RimeDirectory) {
        setWritable(directory, true)
        try? FileManager.default.removeItem(at: directory.root)
    }
}
