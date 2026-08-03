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

    /// Ticket 17: a broken schema that arrives via the Config Folder and is
    /// enabled there must fail the Deploy by name. Before the refinement,
    /// failedSchemas scanned only the shared side, so this failure was
    /// silent — schema enable/disable makes the hole user-reachable.
    func testDeployDetectsBrokenEnabledSchemaFromConfigFolder() throws {
        let engine = try TestEngine.shared.get()
        let directory = TestEngine.directory
        let config = try makeConfigFolder()
        defer {
            try? FileManager.default.removeItem(
                at: directory.user.appendingPathComponent("broken_probe.schema.yaml"))
            try? FileManager.default.removeItem(
                at: directory.user.appendingPathComponent("default.custom.yaml"))
            try? engine.deploy()
        }
        try "garbage: [unclosed\n".write(
            to: config.root.appendingPathComponent("broken_probe.schema.yaml"),
            atomically: true, encoding: .utf8)
        try "patch:\n  schema_list:\n    - schema: luna_pinyin\n    - schema: broken_probe\n"
            .write(to: config.root.appendingPathComponent("default.custom.yaml"),
                   atomically: true, encoding: .utf8)
        _ = try config.sync(into: directory)

        XCTAssertThrowsError(try engine.deploy()) { error in
            guard case Engine.DeployError.schemasFailed(let failed) = error else {
                return XCTFail("expected schemasFailed, got \(error)")
            }
            XCTAssertEqual(failed, ["broken_probe.schema.yaml"])
        }
    }

    /// The refined check covers exactly what the Deploy compiled: a broken
    /// schema source that is NOT enabled is librime's to ignore, so the
    /// Deploy succeeds (scanning both sides' sources would flag it).
    func testDeployIgnoresBrokenDisabledSchemaSource() throws {
        let engine = try TestEngine.shared.get()
        let directory = TestEngine.directory
        let config = try makeConfigFolder()
        defer {
            try? FileManager.default.removeItem(
                at: directory.user.appendingPathComponent("broken_probe.schema.yaml"))
            try? FileManager.default.removeItem(
                at: directory.user.appendingPathComponent("default.custom.yaml"))
            try? engine.deploy()
        }
        try "garbage: [unclosed\n".write(
            to: config.root.appendingPathComponent("broken_probe.schema.yaml"),
            atomically: true, encoding: .utf8)
        try "patch:\n  schema_list:\n    - schema: luna_pinyin\n"
            .write(to: config.root.appendingPathComponent("default.custom.yaml"),
                   atomically: true, encoding: .utf8)
        _ = try config.sync(into: directory)

        XCTAssertNoThrow(try engine.deploy())
    }

    /// The Config Folder seed lands the schema_list switch once — a Files
    /// edit of it is never overwritten (last-write-wins per file).
    func testConfigFolderSeedsOnlyOnce() throws {
        let config = try makeConfigFolder()
        let baseline = Bundle(for: EngineTests.self).resourceURL!
            .appendingPathComponent("rime-baseline", isDirectory: true)

        XCTAssertTrue(try config.seedIfNeeded(from: baseline))
        let marker = config.root.appendingPathComponent("default.custom.yaml")
        XCTAssertTrue(FileManager.default.fileExists(atPath: marker.path))

        try "user edit\n".write(to: marker, atomically: true, encoding: .utf8)
        XCTAssertFalse(try config.seedIfNeeded(from: baseline))
        XCTAssertEqual(try String(contentsOf: marker, encoding: .utf8), "user edit\n")

        // Deleting the file in Files is an edit too — no resurrection.
        try FileManager.default.removeItem(at: marker)
        XCTAssertFalse(try config.seedIfNeeded(from: baseline))
        XCTAssertFalse(FileManager.default.fileExists(atPath: marker.path))
    }

    /// Sync overlays recursively, copies only differing content, skips
    /// dotfiles, and never deletes Rime Directory files.
    func testSyncOverlaysAndNeverDeletes() throws {
        let engine = try TestEngine.shared.get()
        let directory = TestEngine.directory
        let config = try makeConfigFolder()
        defer {
            try? FileManager.default.removeItem(
                at: directory.user.appendingPathComponent("luna_pinyin.custom.yaml"))
            try? FileManager.default.removeItem(
                at: directory.user.appendingPathComponent("opencc/test.json"))
            try? engine.deploy()
        }

        try "patch:\n  menu/page_size: 9\n".write(
            to: config.root.appendingPathComponent("luna_pinyin.custom.yaml"),
            atomically: true, encoding: .utf8)
        let nested = config.root.appendingPathComponent("opencc/test.json")
        try FileManager.default.createDirectory(
            at: nested.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "{}".write(to: nested, atomically: true, encoding: .utf8)
        try "junk".write(
            to: config.root.appendingPathComponent(".DS_Store"), atomically: true, encoding: .utf8)

        XCTAssertEqual(try config.sync(into: directory),
                       ["luna_pinyin.custom.yaml", "opencc/test.json"])
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: directory.user.appendingPathComponent("opencc/test.json").path))
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: directory.user.appendingPathComponent(".DS_Store").path))
        // Pre-existing Rime Directory state survives the sync.
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: directory.user.appendingPathComponent("build").path))

        // Unchanged: a second sync copies nothing.
        XCTAssertEqual(try config.sync(into: directory), [])

        // Edit wins per file: only the edited file copies again.
        try "patch:\n  menu/page_size: 3\n".write(
            to: config.root.appendingPathComponent("luna_pinyin.custom.yaml"),
            atomically: true, encoding: .utf8)
        XCTAssertEqual(try config.sync(into: directory), ["luna_pinyin.custom.yaml"])
    }

    /// The money test (ticket 10 acceptance): edit in the Config Folder →
    /// sync + Deploy → the next Session sees the change. Twice, to prove the
    /// ritual works repeatedly.
    func testEditInConfigFolderReachesKeyboard() throws {
        let engine = try TestEngine.shared.get()
        let directory = TestEngine.directory
        let config = try makeConfigFolder()
        defer {
            try? FileManager.default.removeItem(
                at: directory.user.appendingPathComponent("luna_pinyin.custom.yaml"))
            try? engine.deploy()
        }
        let patch = config.root.appendingPathComponent("luna_pinyin.custom.yaml")

        func candidatesAfterRitual(_ yaml: String, backdate: Bool = false) throws -> Int {
            try yaml.write(to: patch, atomically: true, encoding: .utf8)
            if backdate {
                // librime's rebuild trigger compares second-precision mtimes;
                // backdate the first patch so the second edit always lands in
                // a different second (a non-issue for human rituals).
                try FileManager.default.setAttributes(
                    [.modificationDate: Date(timeIntervalSinceNow: -10)],
                    ofItemAtPath: patch.path)
            }
            _ = try config.sync(into: directory)
            try engine.deploy()
            XCTAssertTrue(engine.startSession())
            defer { engine.endSession() }
            try type("nihao", into: engine)
            return engine.input.candidates.count
        }

        XCTAssertGreaterThan(try candidatesAfterRitual("patch:\n  menu/page_size: 9\n", backdate: true), 5)
        XCTAssertEqual(try candidatesAfterRitual("patch:\n  menu/page_size: 3\n"), 3)
    }

    /// A fresh scratch Config Folder per test (directory created).
    private func makeConfigFolder() throws -> ConfigFolder {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("coriander-config-tests/\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return ConfigFolder(root: root)
    }

    /// A Deploy invalidates the in-progress Session; the next Session loads
    /// the new artifacts even when the Deploy happened outside this process
    /// (ADR-0001) — proven by rewriting the artifact on disk between
    /// Sessions. This is the keyboard's propagation mechanism for Config
    /// Folder changes (ticket 10).
    func testSessionRestartPicksUpNewArtifacts() throws {
        let engine = try TestEngine.shared.get()
        let directory = TestEngine.directory
        let artifact = directory.user.appendingPathComponent("build/luna_pinyin.schema.yaml")
        let backup = try Data(contentsOf: artifact)
        defer {
            try? backup.write(to: artifact)
            try? engine.deploy()
        }

        XCTAssertTrue(engine.startSession())
        try type("nihao", into: engine)
        XCTAssertEqual(engine.input.candidates.count, 5)
        engine.endSession()

        // Simulate the Container App's Deploy: the artifact on disk changes.
        let original = try String(contentsOf: artifact, encoding: .utf8)
        let patched = original.replacingOccurrences(of: "page_size: 5", with: "page_size: 3")
        XCTAssertNotEqual(patched, original, "artifact lacks the expected page_size line")
        try patched.write(to: artifact, atomically: true, encoding: .utf8)

        XCTAssertTrue(engine.startSession())
        defer { engine.endSession() }
        try type("nihao", into: engine)
        XCTAssertEqual(engine.input.candidates.count, 3)
    }

    /// The Config Folder may be reached through a symlinked path (on device,
    /// /var vs /private/var) while the enumerator yields canonical paths —
    /// relative paths must still come out correct (regression: a mangled
    /// "yin.custom.yaml" once landed in the Rime Directory).
    func testSyncResolvesSymlinkedRoot() throws {
        let engine = try TestEngine.shared.get()
        let directory = TestEngine.directory
        defer {
            try? FileManager.default.removeItem(
                at: directory.user.appendingPathComponent("luna_pinyin.custom.yaml"))
            try? engine.deploy()
        }

        // `ln` is a symlink to `realdir`, and the Config Folder is reached
        // through it — mirroring /var vs /private/var on device.
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("coriander-symlink-test/\(UUID().uuidString)", isDirectory: true)
        let realDir = base.appendingPathComponent("realdir", isDirectory: true)
        let realConfig = realDir.appendingPathComponent("Rime Config", isDirectory: true)
        try FileManager.default.createDirectory(at: realConfig, withIntermediateDirectories: true)
        try "patch:\n  menu/page_size: 9\n".write(
            to: realConfig.appendingPathComponent("luna_pinyin.custom.yaml"),
            atomically: true, encoding: .utf8)
        let link = base.appendingPathComponent("ln")
        try FileManager.default.createSymbolicLink(atPath: link.path,
                                                   withDestinationPath: realDir.path)

        let config = ConfigFolder(
            root: link.appendingPathComponent("Rime Config", isDirectory: true))
        let changed = try config.sync(into: directory)
        XCTAssertEqual(changed, ["luna_pinyin.custom.yaml"])
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: directory.user.appendingPathComponent("luna_pinyin.custom.yaml").path))
    }

    /// The Engine offers exactly the Schemas the deployed configuration
    /// enables (probed: librime resolves the list from the deployed default
    /// config). The baseline's default.custom.yaml enables five, in order.
    func testSchemasMatchDeployedEnabledList() throws {
        let engine = try TestEngine.shared.get()
        XCTAssertEqual(engine.schemas.map(\.id), [
            "luna_pinyin", "luna_pinyin_simp", "luna_pinyin_fluency",
            "luna_pinyin_tw", "luna_quanpin",
        ])
        XCTAssertEqual(engine.schemas.first?.name, "朙月拼音")
    }

    /// "Enabled" is config-driven (probed): narrowing schema_list via
    /// default.custom.yaml + Deploy narrows the offered Schemas — the list
    /// itself needs no Session restart.
    func testSchemasHonorDeployedEnabledList() throws {
        let engine = try TestEngine.shared.get()
        let custom = TestEngine.directory.user.appendingPathComponent("default.custom.yaml")
        try "patch:\n  schema_list:\n    - schema: luna_pinyin\n    - schema: luna_pinyin_simp\n"
            .write(to: custom, atomically: true, encoding: .utf8)
        defer {
            try? FileManager.default.removeItem(at: custom)
            try? engine.deploy()
        }
        try engine.deploy()
        XCTAssertEqual(engine.schemas.map(\.id), ["luna_pinyin", "luna_pinyin_simp"])
    }

    /// The selection outlives the Session (probed: librime records it in
    /// user.yaml) — the keyboard keeps the user's choice across text fields
    /// and process restarts.
    func testSchemaSelectionPersistsAcrossSessions() throws {
        let engine = try TestEngine.shared.get()
        XCTAssertTrue(engine.startSession())
        XCTAssertEqual(engine.currentSchemaID, "luna_pinyin")
        XCTAssertTrue(engine.selectSchema("luna_pinyin_simp"))
        engine.endSession()

        XCTAssertTrue(engine.startSession())
        defer {
            // The selection persists — restore it before ending the Session.
            engine.selectSchema("luna_pinyin")
            engine.endSession()
        }
        XCTAssertEqual(engine.currentSchemaID, "luna_pinyin_simp")
    }

    /// librime's select_schema accepts ANY id unchecked (probed: a bogus id
    /// returns true and sticks); the Engine refuses ids outside the enabled
    /// list so no caller can break the "only deployed/enabled" invariant.
    func testSelectSchemaRejectsUnlistedSchema() throws {
        let engine = try TestEngine.shared.get()
        XCTAssertTrue(engine.startSession())
        defer { engine.endSession() }

        XCTAssertFalse(engine.selectSchema("nonexistent_schema"))
        XCTAssertEqual(engine.currentSchemaID, "luna_pinyin")
    }

    /// Switching takes effect inside the live Session (ticket 12 acceptance)
    /// — no Session restart. librime drops the Composition on switch
    /// (probed) and the Session keeps typing on the new Schema.
    func testSelectSchemaSwitchesWithinSession() throws {
        let engine = try TestEngine.shared.get()
        XCTAssertTrue(engine.startSession())
        defer { engine.endSession() }
        // The selection persists across Sessions (probed) — restore it.
        defer { engine.selectSchema("luna_pinyin") }

        XCTAssertEqual(engine.currentSchemaID, "luna_pinyin")
        try type("ni", into: engine)
        XCTAssertFalse(engine.input.composition.isEmpty)

        XCTAssertTrue(engine.selectSchema("luna_pinyin_simp"))
        XCTAssertEqual(engine.currentSchemaID, "luna_pinyin_simp")
        XCTAssertTrue(engine.input.composition.isEmpty,
                      "librime drops the Composition on switch (probed)")

        try type("nihao", into: engine)
        let index = try XCTUnwrap(
            engine.input.candidates.firstIndex(where: { $0.text == "你好" }),
            "expected 你好 among candidates, got \(engine.input.candidates.map(\.text))")
        XCTAssertTrue(engine.selectCandidate(at: index))
        XCTAssertEqual(engine.takeCommit(), "你好")
    }

    /// Types ASCII text into the Engine, one key per character.
    private func type(_ text: String, into engine: Engine) throws {
        for character in text {
            engine.processKey(try XCTUnwrap(Engine.Key(character: character)))
        }
    }
}
