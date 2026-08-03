import XCTest

/// Import with validation and rollback (ticket 21) at the Engine seam.
/// Runs in this target because every test owns its Engine lifecycle on its
/// own scratch Rime Directory + Config Folder — the EngineTests process
/// holds its shared Engine forever.
///
/// Probe findings these tests pin down:
/// - A Deploy silently TOLERATES a broken custom patch (ticket 09), so
///   Import validates yaml syntax itself before anything is written:
///   librime's `config_load_string` parses a yaml source in memory and
///   reports failure — no file, no Deploy.
/// - `*.dict.yaml` is only yaml up to the header-terminating `...` line;
///   the table body below is TSV, so validation stops there.
/// - With pre-Deploy validation in place, imported yaml cannot cause a
///   post-Deploy compile failure at all: librime tolerates even a missing
///   dictionary or `__include` at compile time (it logs and still writes
///   the schema artifact — only unparseable yaml fails the bake). The
///   failedSchemas check is the backstop for failures the Import did not
///   cause (a pre-existing broken config, IO errors).
/// - librime preserves last-good artifacts when a schema compile fails, but
///   a PARTIAL Deploy still bakes imported patches into the artifacts of the
///   schemas that did compile — "typing unchanged" therefore needs the
///   affected artifacts rebuilt from the restored sources, not just the
///   sources rolled back.
final class SchemaImportTests: XCTestCase {
    /// The money test: a valid schema set (schema source + enabling
    /// default.custom.yaml) Imports, Deploys, and types.
    func testImportValidSchemaSetDeploysAndTypes() throws {
        let (config, directory) = try makeWorld("valid")
        defer { removeWorld(config, directory) }
        let staging = try makeStaging("valid")
        defer { try? FileManager.default.removeItem(at: staging) }

        let schema = try stage(staging, "imported_pinyin.schema.yaml",
                               contents: Self.importedSchemaSource)
        let defaults = try stage(staging, "default.custom.yaml",
                                 contents: "patch:\n  schema_list:\n    - schema: luna_pinyin\n    - schema: imported_pinyin\n")

        let report = try SchemaImport.importFiles([schema, defaults],
                                                  into: config, directory: directory)
        XCTAssertEqual(report.added, ["imported_pinyin.schema.yaml"])
        XCTAssertEqual(report.overwritten, ["default.custom.yaml"])
        XCTAssertEqual(Self.fileMap(config.root)["imported_pinyin.schema.yaml"],
                       Data(Self.importedSchemaSource.utf8))

        let verify = try Engine(directory: directory)
        defer { verify.shutdown() }
        XCTAssertTrue(verify.schemas.contains(where: { $0.id == "imported_pinyin" }),
                      "imported Schema not enabled after Deploy: \(verify.schemas.map(\.id))")
        XCTAssertTrue(verify.startSession())
        defer { verify.endSession() }
        XCTAssertTrue(verify.selectSchema("imported_pinyin"))
        try Self.type("nihao", into: verify)
        XCTAssertTrue(verify.input.candidates.contains(where: { $0.text == "你好" }),
                      "typing broke on the imported Schema: \(verify.input.candidates.map(\.text))")
    }

    /// Pre-Deploy validation: a broken custom patch is what a Deploy would
    /// silently tolerate (ticket 09) — Import must reject it by name before
    /// writing anything, leaving the Config Folder byte-identical.
    func testImportRejectsBrokenYamlBeforeWritingAnything() throws {
        let (config, directory) = try makeWorld("brokenyaml")
        defer { removeWorld(config, directory) }
        let staging = try makeStaging("brokenyaml")
        defer { try? FileManager.default.removeItem(at: staging) }
        let before = Self.fileMap(config.root)

        let broken = try stage(staging, "broken.custom.yaml", contents: "patch: [unclosed\n")
        XCTAssertThrowsError(try SchemaImport.importFiles([broken], into: config,
                                                          directory: directory)) { error in
            guard case SchemaImport.ImportError.invalidYaml(let names) = error else {
                return XCTFail("expected invalidYaml, got \(error)")
            }
            XCTAssertEqual(names, ["broken.custom.yaml"])
        }

        XCTAssertEqual(Self.fileMap(config.root), before,
                       "Config Folder changed after a rejected Import")
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: directory.user.appendingPathComponent("broken.custom.yaml").path),
                       "rejected file reached the Rime Directory")
        try assertTypingIntact(directory)
    }

    /// Full rollback on a post-Deploy failure. With pre-Deploy validation in
    /// place, imported yaml can no longer cause a compile failure (probed:
    /// librime tolerates even a missing dictionary or `__include` at compile
    /// time — it logs and still writes the schema artifact; only unparseable
    /// yaml fails, and validation catches that first). The reachable
    /// post-Deploy failure is a config the import did not cause — here the
    /// user broke a schema in Files and enabled it, but has not synced yet.
    /// The Import's sync carries it in, the Deploy bakes the imported
    /// page_size 9 patch into luna_pinyin and THEN fails on the user's
    /// broken schema. After the failure the Config Folder is byte-identical
    /// (the user's broken files untouched — rollback removes only what the
    /// Import itself wrote), the Rime Directory sources are restored, and
    /// typing is back at page_size 5 — proving the affected artifacts were
    /// rebuilt from the restored sources.
    func testImportRollsBackDeployFailureByteIdentical() throws {
        let (config, directory) = try makeWorld("rollback")
        defer { removeWorld(config, directory) }
        let staging = try makeStaging("rollback")
        defer { try? FileManager.default.removeItem(at: staging) }

        // The user's Files edits, not yet synced: a broken schema, enabled,
        // plus a custom patch the Import will overwrite — its prior content
        // is what rollback must restore (overlay may overwrite, never lose).
        try "garbage: [unclosed\n".write(
            to: config.root.appendingPathComponent("broken_user.schema.yaml"),
            atomically: true, encoding: .utf8)
        try "patch:\n  schema_list:\n    - schema: luna_pinyin\n    - schema: broken_user\n"
            .write(to: config.root.appendingPathComponent("default.custom.yaml"),
                   atomically: true, encoding: .utf8)
        let priorPatch = "patch:\n  menu/page_size: 4\n"
        try priorPatch.write(
            to: config.root.appendingPathComponent("luna_pinyin.custom.yaml"),
            atomically: true, encoding: .utf8)
        let before = Self.fileMap(config.root)

        let patch = try stage(staging, "luna_pinyin.custom.yaml",
                              contents: "patch:\n  menu/page_size: 9\n")
        let extra = try stage(staging, "extra.schema.yaml",
                              contents: Self.importedSchemaSource)

        XCTAssertThrowsError(try SchemaImport.importFiles([patch, extra],
                                                          into: config, directory: directory)) { error in
            guard case SchemaImport.ImportError.deployFailed(let detail) = error else {
                return XCTFail("expected deployFailed, got \(error)")
            }
            XCTAssertTrue(detail.contains("broken_user.schema.yaml"),
                          "error did not name the failed schema: \(detail)")
        }

        XCTAssertEqual(Self.fileMap(config.root), before,
                       "Config Folder not byte-identical after rollback")
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: directory.user.appendingPathComponent("extra.schema.yaml").path),
                       "rollback left the imported schema in the Rime Directory")
        XCTAssertFalse(FileManager.default.fileExists(
            atPath: directory.user.appendingPathComponent("luna_pinyin.custom.yaml").path),
                       "rollback left the imported patch in the Rime Directory")

        // Typing is unchanged: last-good artifacts rebuilt from the restored
        // sources — the page_size 9 the partial Deploy baked in is gone.
        let verify = try Engine(directory: directory)
        defer { verify.shutdown() }
        XCTAssertTrue(verify.startSession())
        defer { verify.endSession() }
        try Self.type("nihao", into: verify)
        XCTAssertLessThanOrEqual(verify.input.candidates.count, 5,
                                 "a failed Import leaked its patch into the artifacts")
        XCTAssertTrue(verify.input.candidates.contains(where: { $0.text == "你好" }))
    }

    /// Overlay semantics (ticket 17 story): an archive Import adds new files
    /// and overwrites same-named ones but never deletes; a repeated Import
    /// of identical content is a no-op; a changed archive overwrites.
    func testImportArchiveOverlaysAndRepeatsSafely() throws {
        let (config, directory) = try makeWorld("overlay")
        defer { removeWorld(config, directory) }
        let staging = try makeStaging("overlay")
        defer { try? FileManager.default.removeItem(at: staging) }
        let keep = config.root.appendingPathComponent("keep.txt")
        try "user file\n".write(to: keep, atomically: true, encoding: .utf8)

        let archive = staging.appendingPathComponent("set.zip")
        try ZipArchive.write(entries: [
            ZipArchive.Entry(name: "archived.schema.yaml", data: Data(Self.importedSchemaSource.utf8)),
            ZipArchive.Entry(name: "luna_pinyin.custom.yaml",
                             data: Data("patch:\n  menu/page_size: 9\n".utf8)),
        ], to: archive)
        let source = SchemaImport.Source(name: "set.zip", url: archive)

        let first = try SchemaImport.importFiles([source], into: config, directory: directory)
        XCTAssertEqual(first.added, ["archived.schema.yaml", "luna_pinyin.custom.yaml"])
        XCTAssertEqual(first.overwritten, [])
        XCTAssertEqual(try String(contentsOf: keep, encoding: .utf8), "user file\n",
                       "Import deleted an unrelated Config Folder file")

        // The archived schema is not enabled, but the patch took effect.
        let paged = try Engine(directory: directory)
        XCTAssertTrue(paged.startSession())
        try Self.type("nihao", into: paged)
        XCTAssertGreaterThan(paged.input.candidates.count, 5,
                             "imported patch did not reach the artifacts")
        paged.endSession()
        paged.shutdown()

        // A repeated identical Import changes nothing.
        let mapAfterFirst = Self.fileMap(config.root)
        let second = try SchemaImport.importFiles([source], into: config, directory: directory)
        XCTAssertEqual(second, SchemaImport.Report(added: [], overwritten: []))
        XCTAssertEqual(Self.fileMap(config.root), mapAfterFirst,
                       "a repeated Import was not a no-op")

        // A changed archive overwrites the same-named file (librime's
        // rebuild trigger compares second-precision mtimes — wait out the
        // same-second window before re-importing, like the Config Folder
        // tests backdate).
        Thread.sleep(forTimeInterval: 1.1)
        try ZipArchive.write(entries: [
            ZipArchive.Entry(name: "luna_pinyin.custom.yaml",
                             data: Data("patch:\n  menu/page_size: 3\n".utf8)),
        ], to: archive)
        let third = try SchemaImport.importFiles([source], into: config, directory: directory)
        XCTAssertEqual(third, SchemaImport.Report(added: [], overwritten: ["luna_pinyin.custom.yaml"]))
        XCTAssertTrue(FileManager.default.fileExists(
            atPath: config.root.appendingPathComponent("archived.schema.yaml").path),
                       "a later archive deleted an earlier Import's file")

        let narrowed = try Engine(directory: directory)
        defer { narrowed.shutdown() }
        XCTAssertTrue(narrowed.startSession())
        defer { narrowed.endSession() }
        try Self.type("nihao", into: narrowed)
        XCTAssertEqual(narrowed.input.candidates.count, 3,
                       "overwritten patch did not reach the artifacts")
    }

    /// ZipArchive reads STORE entries only; a compressed archive is rejected
    /// by name with nothing written (crafted by flipping the method byte of
    /// an archive written by ZipArchive itself).
    func testImportRejectsCompressedArchiveEntries() throws {
        let (config, directory) = try makeWorld("deflate")
        defer { removeWorld(config, directory) }
        let staging = try makeStaging("deflate")
        defer { try? FileManager.default.removeItem(at: staging) }
        let before = Self.fileMap(config.root)

        let archive = staging.appendingPathComponent("deflated.zip")
        try ZipArchive.write(entries: [ZipArchive.Entry(name: "a.yaml", data: Data("a: 1\n".utf8))],
                             to: archive)
        var bytes = try Data(contentsOf: archive)
        bytes[8] = 8 // local header method: store → deflate
        let signature = Data([0x50, 0x4b, 0x01, 0x02]) // central directory header
        let central = try XCTUnwrap(bytes.range(of: signature)?.lowerBound,
                                    "crafted archive lost its central directory")
        bytes[central + 10] = 8 // central header method
        try bytes.write(to: archive)

        XCTAssertThrowsError(try SchemaImport.importFiles(
            [SchemaImport.Source(name: "deflated.zip", url: archive)],
            into: config, directory: directory)) { error in
            guard case SchemaImport.ImportError.unreadableArchive(let name, _) = error else {
                return XCTFail("expected unreadableArchive, got \(error)")
            }
            XCTAssertEqual(name, "deflated.zip")
        }
        XCTAssertEqual(Self.fileMap(config.root), before)
    }

    /// A garbage file named .zip is rejected, not written.
    func testImportRejectsGarbageArchive() throws {
        let (config, directory) = try makeWorld("garbage")
        defer { removeWorld(config, directory) }
        let staging = try makeStaging("garbage")
        defer { try? FileManager.default.removeItem(at: staging) }
        let before = Self.fileMap(config.root)

        let archive = staging.appendingPathComponent("junk.zip")
        try "this is not a zip".write(to: archive, atomically: true, encoding: .utf8)

        XCTAssertThrowsError(try SchemaImport.importFiles(
            [SchemaImport.Source(name: "junk.zip", url: archive)],
            into: config, directory: directory)) { error in
            guard case SchemaImport.ImportError.unreadableArchive(let name, _) = error else {
                return XCTFail("expected unreadableArchive, got \(error)")
            }
            XCTAssertEqual(name, "junk.zip")
        }
        XCTAssertEqual(Self.fileMap(config.root), before)
    }

    /// Loose-file Imports are yaml-only (ticket 21 scope); anything else is
    /// rejected by name with nothing written.
    func testImportRejectsNonYamlLooseFile() throws {
        let (config, directory) = try makeWorld("nonyaml")
        defer { removeWorld(config, directory) }
        let staging = try makeStaging("nonyaml")
        defer { try? FileManager.default.removeItem(at: staging) }
        let before = Self.fileMap(config.root)

        let notes = try stage(staging, "notes.txt", contents: "hello\n")
        XCTAssertThrowsError(try SchemaImport.importFiles([notes], into: config,
                                                          directory: directory)) { error in
            guard case SchemaImport.ImportError.unsupportedFile(let name) = error else {
                return XCTFail("expected unsupportedFile, got \(error)")
            }
            XCTAssertEqual(name, "notes.txt")
        }
        XCTAssertEqual(Self.fileMap(config.root), before)
    }

    /// An empty offer is an honest error, not a vacuous success.
    func testImportRejectsEmptyOffer() throws {
        let (config, directory) = try makeWorld("empty")
        defer { removeWorld(config, directory) }
        XCTAssertThrowsError(try SchemaImport.importFiles([], into: config, directory: directory)) { error in
            guard case SchemaImport.ImportError.nothingToImport = error else {
                return XCTFail("expected nothingToImport, got \(error)")
            }
        }
    }

    /// A dictionary's TSV body is not yaml: an entry line that would break a
    /// whole-file parse passes, while a broken yaml HEADER is rejected.
    func testImportValidatesDictionaryHeaderNotTableBody() throws {
        let (config, directory) = try makeWorld("dict")
        defer { removeWorld(config, directory) }
        let staging = try makeStaging("dict")
        defer { try? FileManager.default.removeItem(at: staging) }

        let good = try stage(staging, "test_dict.dict.yaml", contents: """
        ---
        name: test_dict
        version: '1'
        sort: by_weight
        ...
        [unclosed-tsv-line	is fine	below the header
        你好	ni hao	100

        """)
        XCTAssertNoThrow(try SchemaImport.importFiles([good], into: config, directory: directory))
        XCTAssertNotNil(Self.fileMap(config.root)["test_dict.dict.yaml"])

        let bad = try stage(staging, "bad_dict.dict.yaml", contents: """
        ---
        name: [unclosed
        ...
        你好	ni hao	100

        """)
        XCTAssertThrowsError(try SchemaImport.importFiles([bad], into: config, directory: directory)) { error in
            guard case SchemaImport.ImportError.invalidYaml(let names) = error else {
                return XCTFail("expected invalidYaml, got \(error)")
            }
            XCTAssertEqual(names, ["bad_dict.dict.yaml"])
        }
        XCTAssertNil(Self.fileMap(config.root)["bad_dict.dict.yaml"])
    }

    /// A multi-file offer is validated as a unit: one broken file rejects
    /// the whole offer and nothing — not even the valid files — is written.
    func testImportMultiFileRejectionWritesNothing() throws {
        let (config, directory) = try makeWorld("multi")
        defer { removeWorld(config, directory) }
        let staging = try makeStaging("multi")
        defer { try? FileManager.default.removeItem(at: staging) }
        let before = Self.fileMap(config.root)

        let good = try stage(staging, "good.custom.yaml",
                             contents: "patch:\n  menu/page_size: 9\n")
        let broken = try stage(staging, "broken.custom.yaml", contents: "patch: [unclosed\n")
        XCTAssertThrowsError(try SchemaImport.importFiles([good, broken], into: config,
                                                          directory: directory)) { error in
            guard case SchemaImport.ImportError.invalidYaml(let names) = error else {
                return XCTFail("expected invalidYaml, got \(error)")
            }
            XCTAssertEqual(names, ["broken.custom.yaml"])
        }
        XCTAssertEqual(Self.fileMap(config.root), before,
                       "a partially valid offer left files behind")
        try assertTypingIntact(directory)
    }

    // MARK: helpers

    /// A working Schema source: the baseline luna_pinyin copied under a new
    /// id (its dictionary resolves from the shared baseline).
    private static var importedSchemaSource: String {
        let baseline = Bundle(for: SchemaImportTests.self).resourceURL!
            .appendingPathComponent("rime-baseline/luna_pinyin.schema.yaml")
        let text = try! String(contentsOf: baseline, encoding: .utf8)
        return text
            .replacingOccurrences(of: "schema_id: luna_pinyin", with: "schema_id: imported_pinyin")
            .replacingOccurrences(of: "name: 朙月拼音", with: "name: 導入測試")
    }

    /// A scratch Config Folder seeded like first launch, plus a scratch
    /// Rime Directory seeded, synced, and Deployed — the steady state an
    /// Import runs against.
    private func makeWorld(_ name: String) throws -> (ConfigFolder, RimeDirectory) {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent("coriander-import-tests/\(name)-\(UUID().uuidString)",
                                    isDirectory: true)
        let config = ConfigFolder(root: base.appendingPathComponent("config", isDirectory: true))
        let directory = RimeDirectory(root: base.appendingPathComponent("rime", isDirectory: true))
        let baseline = Bundle(for: SchemaImportTests.self).resourceURL!
            .appendingPathComponent("rime-baseline", isDirectory: true)
        try directory.seed(from: baseline)
        try config.seedIfNeeded(from: baseline)
        _ = try config.sync(into: directory)
        let engine = try Engine(directory: directory)
        defer { engine.shutdown() }
        try engine.deploy()
        return (config, directory)
    }

    private func removeWorld(_ config: ConfigFolder, _ directory: RimeDirectory) {
        try? FileManager.default.removeItem(at: config.root.deletingLastPathComponent())
    }

    /// A scratch staging folder holding the files an offer is built from
    /// (the app layer stages picker/share-sheet URLs the same way).
    private func makeStaging(_ name: String) throws -> URL {
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("coriander-import-tests/staging-\(name)-\(UUID().uuidString)",
                                    isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        return staging
    }

    private func stage(_ staging: URL, _ name: String, contents: String) throws -> SchemaImport.Source {
        let url = staging.appendingPathComponent(name)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return SchemaImport.Source(name: name, url: url)
    }

    /// The Config Folder's recursive content map (relative path → bytes) for
    /// byte-identity assertions.
    private static func fileMap(_ root: URL) -> [String: Data] {
        let fm = FileManager.default
        let rootPath = root.resolvingSymlinksInPath().path
        let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey])
        var map: [String: Data] = [:]
        while let file = enumerator?.nextObject() as? URL {
            guard (try? file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true else { continue }
            let relative = String(file.resolvingSymlinksInPath().path.dropFirst(rootPath.count + 1))
            map[relative] = try? Data(contentsOf: file)
        }
        return map
    }

    private func assertTypingIntact(_ directory: RimeDirectory,
                                    file: StaticString = #filePath, line: UInt = #line) throws {
        let verify = try Engine(directory: directory)
        defer { verify.shutdown() }
        XCTAssertTrue(verify.startSession(), file: file, line: line)
        defer { verify.endSession() }
        try Self.type("nihao", into: verify)
        XCTAssertTrue(verify.input.candidates.contains(where: { $0.text == "你好" }),
                      "typing broke after a failed Import", file: file, line: line)
    }

    private static func type(_ text: String, into engine: Engine) throws {
        for character in text {
            engine.processKey(try XCTUnwrap(Engine.Key(character: character)))
        }
    }
}
