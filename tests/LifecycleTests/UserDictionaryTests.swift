import XCTest

/// Export, restore, and clear for the User Dictionary (ticket 15), probed
/// then kept as regression coverage at the Engine seam. Runs in this target
/// because every test owns its Engine lifecycle on its own scratch
/// directory — the EngineTests process holds its shared Engine forever.
///
/// Probe findings these tests pin down:
/// - librime's only user-dict management primitives that take explicit paths
///   are the levers `export_user_dict` / `import_user_dict` (TSV dumps).
///   `backup_user_dict` writes to a CWD-relative sync dir and rewrites
///   userdb metadata; `restore_user_dict` needs that snapshot format;
///   `sync_user_data` fails outside a maintenance context; the levers
///   `user_dict_iterator` fails to init — dict names come from a `*.userdb`
///   file scan.
/// - Import MERGES (librime has no replace); after a clear that is a full
///   round-trip.
/// - A live Session holds the dictionary's LevelDB lock ("already held by
///   process") and levers calls then fail with -1 — cleanly, no crash. On a
///   read-only user side (the app-side shape when the keyboard holds the
///   lock cross-process) they fail the same way.
/// - Deleting a userdb under a live writer is POSIX unlink: the holder
///   keeps typing on its unlinked handles, the next Engine starts over
///   empty. No corruption either way.
final class UserDictionaryTests: XCTestCase {
    /// The export archive holds exactly one `<dict>.userdb.txt` TSV dump per
    /// User Dictionary — nothing else on the user side is persistent user
    /// state (probed layout: `build/` artifacts, `user.yaml` and
    /// `installation.yaml` bookkeeping, all reproducible).
    func testExportProducesOneEntryPerDictionary() throws {
        let directory = try Self.makeDirectory("export")
        defer { Self.remove(directory) }
        try Self.deploy(directory)
        let engine = try Engine(directory: directory)
        try Self.learn(Self.input, picking: ["諾", "吐"], expect: Self.coined, into: engine)
        engine.shutdown()

        let folder = try Self.makeFolder("exports")
        let archive = try Self.exportFixed(directory, into: folder)
        defer { try? FileManager.default.removeItem(at: folder) }

        XCTAssertEqual(archive.deletingPathExtension().lastPathComponent,
                       "coriander-userdict-fixed")
        let entries = try ZipArchive.readEntries(from: archive)
        XCTAssertEqual(entries.map(\.name), ["luna_pinyin.userdb.txt"])
        let dump = try XCTUnwrap(entries.first?.data)
        XCTAssertTrue(String(decoding: dump, as: UTF8.self).contains(Self.coined),
                      "coined word missing from the exported dump")
    }

    /// The ticket's money test: export → clear → restore brings the learned
    /// word back, ranking first again — the round-trip the spec asks to note.
    func testExportClearRestoreRoundTripsLearnedWords() throws {
        let directory = try Self.makeDirectory("roundtrip")
        defer { Self.remove(directory) }
        try Self.deploy(directory)
        let engine = try Engine(directory: directory)
        try Self.learn(Self.input, picking: ["諾", "吐"], expect: Self.coined, into: engine)
        engine.shutdown()

        let folder = try Self.makeFolder("exports")
        defer { try? FileManager.default.removeItem(at: folder) }
        let archive = try UserDictionary.export(directory: directory, into: folder)

        XCTAssertEqual(try UserDictionary.clear(directory: directory), ["luna_pinyin"])
        XCTAssertTrue(FileManager.default.fileExists(atPath: directory.user
            .appendingPathComponent("build", isDirectory: true).path),
                      "clear touched more than the User Dictionary")

        // After the clear the word is gone from a fresh Engine.
        let cleared = try Engine(directory: directory)
        XCTAssertTrue(cleared.startSession())
        try Self.type(Self.input, into: cleared)
        XCTAssertNotEqual(cleared.input.candidates.first?.text, Self.coined,
                          "cleared dictionary still offers the coined word")
        cleared.endSession()
        cleared.shutdown()

        XCTAssertEqual(try UserDictionary.restore(archive: archive, into: directory),
                       ["luna_pinyin"])

        let verify = try Engine(directory: directory)
        defer { verify.shutdown() }
        XCTAssertTrue(verify.startSession())
        defer { verify.endSession() }
        try Self.type(Self.input, into: verify)
        XCTAssertEqual(verify.input.candidates.first?.text, Self.coined,
                       "restore did not bring the coined word back")
    }

    /// Restore merges (probed): learning that happened after the export
    /// survives the restore.
    func testRestoreMergesPreservingNewerLearning() throws {
        let directory = try Self.makeDirectory("merge")
        defer { Self.remove(directory) }
        try Self.deploy(directory)
        let engine = try Engine(directory: directory)
        try Self.learn(Self.input, picking: ["諾", "吐"], expect: Self.coined, into: engine)
        engine.shutdown()

        let folder = try Self.makeFolder("exports")
        defer { try? FileManager.default.removeItem(at: folder) }
        let archive = try UserDictionary.export(directory: directory, into: folder)

        // 夠澤 for "gouze" is the same proven-coinable pair LearningTests uses.
        let second = try Engine(directory: directory)
        try Self.learn("gouze", picking: ["夠", "澤"], expect: "夠澤", into: second)
        second.shutdown()

        XCTAssertEqual(try UserDictionary.restore(archive: archive, into: directory),
                       ["luna_pinyin"])

        let verify = try Engine(directory: directory)
        defer { verify.shutdown() }
        XCTAssertTrue(verify.startSession())
        defer { verify.endSession() }
        try Self.type(Self.input, into: verify)
        XCTAssertEqual(verify.input.candidates.first?.text, Self.coined)
        verify.clearComposition()
        try Self.type("gouze", into: verify)
        XCTAssertEqual(verify.input.candidates.first?.text, "夠澤",
                       "post-export learning was clobbered by the restore")
    }

    /// Single-writer, clear half: clearing while an Engine holds a Session
    /// (the keyboard mid-typing) neither crashes nor corrupts — the live
    /// Engine keeps typing on its unlinked handles, the next one starts
    /// over empty.
    func testClearUnderLiveEngineKeepsTyping() throws {
        let directory = try Self.makeDirectory("clearlive")
        defer { Self.remove(directory) }
        try Self.deploy(directory)
        let engine = try Engine(directory: directory)
        try Self.learn(Self.input, picking: ["諾", "吐"], expect: Self.coined, into: engine)

        XCTAssertTrue(engine.startSession())
        XCTAssertEqual(try UserDictionary.clear(directory: directory), ["luna_pinyin"])
        try Self.type("nihao", into: engine)
        XCTAssertTrue(engine.input.candidates.contains(where: { $0.text == "你好" }),
                      "typing broke after clearing under a live engine")
        XCTAssertTrue(engine.processKey(.space))
        XCTAssertNotNil(engine.takeCommit())
        engine.endSession()
        engine.shutdown()

        let fresh = try Engine(directory: directory)
        defer { fresh.shutdown() }
        XCTAssertTrue(fresh.startSession())
        defer { fresh.endSession() }
        try Self.type(Self.input, into: fresh)
        XCTAssertNotEqual(fresh.input.candidates.first?.text, Self.coined,
                          "cleared dictionary still offers the coined word")
        fresh.clearComposition()
        try Self.type("nihao", into: fresh)
        XCTAssertTrue(fresh.input.candidates.contains(where: { $0.text == "你好" }))
    }

    /// ENG-69 regression: a Clear landing under a live Session (the warm
    /// keyboard process) must take effect on a SESSION RESTART — the
    /// keyboard's response to the generation bump on its next appearance —
    /// not minutes later when iOS reaps the process. The first half pins
    /// the bug shape (POSIX unlink keeps the holder serving its store); the
    /// second half pins that a same-Engine Session restart reopens the
    /// cleared store, learning resumes, and the re-learned word exports.
    func testClearUnderLiveSessionTakesEffectOnSessionRestart() throws {
        let directory = try Self.makeDirectory("clearrestart")
        defer { Self.remove(directory) }
        try Self.deploy(directory)
        let engine = try Engine(directory: directory)
        try Self.learn(Self.input, picking: ["諾", "吐"], expect: Self.coined, into: engine)

        // The warm keyboard: one Session spanning the Clear.
        XCTAssertTrue(engine.startSession())
        XCTAssertEqual(try UserDictionary.clear(directory: directory), ["luna_pinyin"])
        try Self.type(Self.input, into: engine)
        XCTAssertEqual(engine.input.candidates.first?.text, Self.coined,
                       "the live Session should still serve its unlinked store")
        engine.clearComposition()

        // What the keyboard does when the generation bridge changes.
        engine.endSession()
        XCTAssertTrue(engine.startSession())
        try Self.type(Self.input, into: engine)
        XCTAssertNotEqual(engine.input.candidates.first?.text, Self.coined,
                          "cleared word survived the Session restart")
        engine.endSession()

        // Learning resumes into the fresh store and exports normally.
        try Self.learn(Self.input, picking: ["諾", "吐"], expect: Self.coined, into: engine)
        engine.shutdown()

        let folder = try Self.makeFolder("exports")
        defer { try? FileManager.default.removeItem(at: folder) }
        let archive = try UserDictionary.export(directory: directory, into: folder)
        let entries = try ZipArchive.readEntries(from: archive)
        let dump = try XCTUnwrap(entries.first?.data)
        XCTAssertTrue(String(decoding: dump, as: UTF8.self).contains(Self.coined),
                      "re-learned word missing from the export")
    }

    /// Single-writer, export/restore half: with the user side read-only
    /// (the app-side shape when the keyboard holds the LevelDB lock), the
    /// ops fail cleanly — an honest error, no partial archive.
    func testExportOnReadOnlyUserSideFailsCleanly() throws {
        let directory = try Self.makeDirectory("contention")
        try Self.deploy(directory)
        defer {
            Self.setWritable(directory, true)
            Self.remove(directory)
        }
        let engine = try Engine(directory: directory)
        try Self.learn(Self.input, picking: ["諾", "吐"], expect: Self.coined, into: engine)
        engine.shutdown()

        Self.setWritable(directory, false)
        let folder = try Self.makeFolder("exports")
        defer { try? FileManager.default.removeItem(at: folder) }
        XCTAssertThrowsError(try UserDictionary.export(directory: directory, into: folder)) { error in
            guard case Engine.ManagementError.exportFailed = error else {
                return XCTFail("expected exportFailed, got \(error)")
            }
        }
        XCTAssertEqual(Self.folderContents(folder), [],
                       "a partial archive was left behind")
    }

    /// The Engine refuses management ops while a Session holds the lock.
    func testManagementOpsNeedNoOpenSession() throws {
        let directory = try Self.makeDirectory("session")
        defer { Self.remove(directory) }
        try Self.deploy(directory)
        let engine = try Engine(directory: directory)
        defer { engine.shutdown() }
        try Self.learn(Self.input, picking: ["諾", "吐"], expect: Self.coined, into: engine)

        XCTAssertTrue(engine.startSession())
        defer { engine.endSession() }
        let dump = FileManager.default.temporaryDirectory
            .appendingPathComponent("coriander-test-\(UUID().uuidString).txt")
        XCTAssertThrowsError(try engine.exportUserDictionary("luna_pinyin", to: dump)) { error in
            guard case Engine.ManagementError.sessionOpen = error else {
                return XCTFail("expected sessionOpen, got \(error)")
            }
        }
        XCTAssertThrowsError(try engine.importUserDictionary("luna_pinyin", from: dump)) { error in
            guard case Engine.ManagementError.sessionOpen = error else {
                return XCTFail("expected sessionOpen, got \(error)")
            }
        }
    }

    /// Nothing learned yet → an honest "nothing to export", not an empty
    /// archive.
    func testExportWithNoDictionariesThrows() throws {
        let directory = try Self.makeDirectory("empty")
        defer { Self.remove(directory) }
        try Self.deploy(directory)
        let folder = try Self.makeFolder("exports")
        defer { try? FileManager.default.removeItem(at: folder) }
        XCTAssertThrowsError(try UserDictionary.export(directory: directory, into: folder)) { error in
            guard case UserDictionary.ManagementError.nothingToExport = error else {
                return XCTFail("expected nothingToExport, got \(error)")
            }
        }
    }

    /// A zip without `<dict>.userdb.txt` entries is not one of ours.
    func testRestoreRejectsForeignArchive() throws {
        let directory = try Self.makeDirectory("foreign")
        defer { Self.remove(directory) }
        try Self.deploy(directory)
        let folder = try Self.makeFolder("exports")
        defer { try? FileManager.default.removeItem(at: folder) }
        let archive = folder.appendingPathComponent("foreign.zip")
        try ZipArchive.write(entries: [ZipArchive.Entry(name: "readme.txt",
                                                        data: Data("hi".utf8))],
                             to: archive)
        XCTAssertThrowsError(try UserDictionary.restore(archive: archive, into: directory)) { error in
            guard case UserDictionary.ManagementError.noDictionariesInArchive = error else {
                return XCTFail("expected noDictionariesInArchive, got \(error)")
            }
        }
    }

    // MARK: helpers

    private static let input = "nuotu"
    private static let coined = "諾吐"

    /// Exports always with one fixed name so tests can assert on it.
    private static func exportFixed(_ directory: RimeDirectory, into folder: URL) throws -> URL {
        try UserDictionary.export(directory: directory, into: folder,
                                  archiveName: "coriander-userdict-fixed.zip")
    }

    /// Coins a word by picking its characters one at a time and verifies it
    /// persisted (ranks first on the next Session). Partial selections do
    /// not Commit; one Commit lands when the last segment is picked (probed).
    private static func learn(_ input: String, picking characters: [String],
                      expect coined: String, into engine: Engine) throws {
        XCTAssertTrue(engine.startSession())
        try type(input, into: engine)
        for (index, character) in characters.enumerated() {
            try select(character, from: engine)
            if index < characters.count - 1 {
                XCTAssertNil(engine.takeCommit())
            }
        }
        XCTAssertEqual(engine.takeCommit(), coined)
        engine.endSession()

        XCTAssertTrue(engine.startSession())
        try type(input, into: engine)
        XCTAssertEqual(engine.input.candidates.first?.text, coined,
                       "\(coined) did not persist: \(engine.input.candidates.map(\.text))")
        engine.endSession()
    }

    private static func makeDirectory(_ name: String) throws -> RimeDirectory {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("coriander-userdict-tests/\(name)-\(UUID().uuidString)",
                                    isDirectory: true)
        let directory = RimeDirectory(root: root)
        let baseline = Bundle(for: UserDictionaryTests.self).resourceURL!
            .appendingPathComponent("rime-baseline", isDirectory: true)
        try directory.seed(from: baseline)
        return directory
    }

    private static func makeFolder(_ name: String) throws -> URL {
        let folder = FileManager.default.temporaryDirectory
            .appendingPathComponent("coriander-userdict-tests/\(name)-\(UUID().uuidString)",
                                    isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

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

    private static func select(_ text: String, from engine: Engine) throws {
        let index = try XCTUnwrap(
            engine.input.candidates.firstIndex(where: { $0.text == text }),
            "\(text) not among candidates: \(engine.input.candidates.map(\.text))")
        XCTAssertTrue(engine.selectCandidate(at: index))
    }

    private static func folderContents(_ folder: URL) -> [String] {
        (try? FileManager.default.contentsOfDirectory(atPath: folder.path)) ?? []
    }

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

    private static func remove(_ directory: RimeDirectory) {
        setWritable(directory, true)
        try? FileManager.default.removeItem(at: directory.root)
    }
}
