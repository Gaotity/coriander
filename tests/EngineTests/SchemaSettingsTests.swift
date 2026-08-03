import XCTest

/// Rime-layer settings (ticket 17) at the Config Folder seam: the enabled,
/// ordered Schema list round-trips through `default.custom.yaml`, writes
/// preserve the user's other patch keys (last-write-wins is per file, but
/// settings owns only the schema_list block), and a settings write reaches
/// the Engine's offered Schemas through the sync + Deploy ritual — no
/// shadow state.
final class SchemaSettingsTests: XCTestCase {
    /// entries come from the seeded Config Folder: the baseline's five
    /// enabled in schema_list order, names parsed from the shared sources.
    func testEntriesReflectSeededSchemaList() throws {
        let (settings, _) = try makeSeededSettings()
        XCTAssertEqual(settings.entries.map(\.id), [
            "luna_pinyin", "luna_pinyin_simp", "luna_pinyin_fluency",
            "luna_pinyin_tw", "luna_quanpin",
        ])
        XCTAssertTrue(settings.entries.allSatisfy(\.enabled))
        XCTAssertEqual(settings.entries.first?.name, "朙月拼音")
    }

    /// save writes the enabled ids in the given order; disabled sources
    /// stay available (sorted by id) for re-enabling.
    func testSaveReordersAndDisables() throws {
        let (settings, config) = try makeSeededSettings()
        try settings.save(enabledIDs: ["luna_quanpin", "luna_pinyin"])

        XCTAssertEqual(settings.enabledIDs(), ["luna_quanpin", "luna_pinyin"])
        XCTAssertEqual(settings.entries.filter(\.enabled).map(\.id),
                       ["luna_quanpin", "luna_pinyin"])
        XCTAssertEqual(settings.entries.filter { !$0.enabled }.map(\.id),
                       ["luna_pinyin_fluency", "luna_pinyin_simp", "luna_pinyin_tw"])
        let file = try String(contentsOf: config.root.appendingPathComponent("default.custom.yaml"),
                              encoding: .utf8)
        XCTAssertTrue(file.hasPrefix("patch:\n  schema_list:\n    - schema: luna_quanpin\n    - schema: luna_pinyin\n"),
                      "unexpected file shape: \(file)")
    }

    /// A write replaces only the schema_list block: other patch keys and
    /// comments the user added in Files survive (ADR-0002).
    func testSavePreservesOtherPatchKeysAndComments() throws {
        let config = try makeConfigFolder()
        let settings = SchemaSettings(config: config, directory: TestEngine.directory)
        let file = config.root.appendingPathComponent("default.custom.yaml")
        try """
        patch:
          switcher/hotkeys:
            - F4
          schema_list:
            - schema: luna_pinyin
          # keep me

        """.write(to: file, atomically: true, encoding: .utf8)

        try settings.save(enabledIDs: ["luna_quanpin"])

        let text = try String(contentsOf: file, encoding: .utf8)
        XCTAssertEqual(text, """
        patch:
          switcher/hotkeys:
            - F4
          schema_list:
            - schema: luna_quanpin
          # keep me

        """)
    }

    /// A patch without a schema_list gains one right under `patch:`.
    func testSaveInsertsSchemaListUnderExistingPatch() throws {
        let config = try makeConfigFolder()
        let settings = SchemaSettings(config: config, directory: TestEngine.directory)
        let file = config.root.appendingPathComponent("default.custom.yaml")
        try "patch:\n  some_key: 1\n".write(to: file, atomically: true, encoding: .utf8)

        try settings.save(enabledIDs: ["luna_pinyin"])

        XCTAssertEqual(try String(contentsOf: file, encoding: .utf8),
                       "patch:\n  schema_list:\n    - schema: luna_pinyin\n  some_key: 1\n")
    }

    /// A missing default.custom.yaml is created from scratch.
    func testSaveCreatesFileWhenMissing() throws {
        let config = try makeConfigFolder()
        let settings = SchemaSettings(config: config, directory: TestEngine.directory)

        try settings.save(enabledIDs: ["luna_pinyin"])

        XCTAssertEqual(
            try String(contentsOf: config.root.appendingPathComponent("default.custom.yaml"),
                       encoding: .utf8),
            "patch:\n  schema_list:\n    - schema: luna_pinyin\n")
    }

    /// A schema source dropped into the Config Folder (e.g. via Files)
    /// shows up disabled-but-available, named from its `schema/name`.
    func testConfigFolderSchemaSourceIsAvailableWithParsedName() throws {
        let (settings, config) = try makeSeededSettings()
        try """
        schema:
          schema_id: my_schema
          name: '我的方案'

        """.write(to: config.root.appendingPathComponent("my_schema.schema.yaml"),
                  atomically: true, encoding: .utf8)

        let entry = settings.entries.first(where: { $0.id == "my_schema" })
        XCTAssertEqual(entry, SchemaSettings.Entry(id: "my_schema", name: "我的方案", enabled: false))
    }

    /// An enabled id with no source on either side stays listed (the Deploy
    /// will report it), named by its id.
    func testEnabledSchemaWithoutSourceFallsBackToID() throws {
        let (settings, _) = try makeSeededSettings()
        try settings.save(enabledIDs: ["ghost_schema"])
        XCTAssertEqual(settings.entries.first,
                       SchemaSettings.Entry(id: "ghost_schema", name: "ghost_schema", enabled: true))
    }

    /// The money test (ticket 17 acceptance): reorder + narrow via settings
    /// → the file lands in the Config Folder → sync + Deploy → the Engine
    /// offers exactly the new list, in the new order.
    func testSettingsWriteReachesEngineThroughDeploy() throws {
        let engine = try TestEngine.shared.get()
        let directory = TestEngine.directory
        let (settings, config) = try makeSeededSettings()
        defer {
            try? FileManager.default.removeItem(
                at: directory.user.appendingPathComponent("default.custom.yaml"))
            try? engine.deploy()
        }

        try settings.save(enabledIDs: ["luna_quanpin", "luna_pinyin"])
        _ = try config.sync(into: directory)
        try engine.deploy()

        XCTAssertEqual(engine.schemas.map(\.id), ["luna_quanpin", "luna_pinyin"])
    }

    /// A scratch Config Folder seeded with the baseline's
    /// default.custom.yaml, plus the settings over it.
    private func makeSeededSettings() throws -> (SchemaSettings, ConfigFolder) {
        let config = try makeConfigFolder()
        let baseline = Bundle(for: SchemaSettingsTests.self).resourceURL!
            .appendingPathComponent("rime-baseline", isDirectory: true)
        try config.seedIfNeeded(from: baseline)
        return (SchemaSettings(config: config, directory: TestEngine.directory), config)
    }

    /// A fresh scratch Config Folder per test (directory created).
    private func makeConfigFolder() throws -> ConfigFolder {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("coriander-schema-settings-tests/\(UUID().uuidString)",
                                    isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return ConfigFolder(root: root)
    }
}
