import Foundation

/// Rime-layer settings (ticket 17): the enabled, ordered Schema list. The
/// single source of truth is the Config Folder's `default.custom.yaml`
/// (ADR-0002) — reading and writing both go through that file, so the
/// settings UI never carries shadow state. Writing replaces only the
/// `schema_list` block under `patch:`; any other keys the user added in
/// Files survive the write. Schemas available for enabling are the
/// top-level `*.schema.yaml` sources in the Config Folder and the Rime
/// Directory's `shared` side (a Config Folder copy shadows the shared one,
/// mirroring librime's user-first resolution); display names come from each
/// source's `schema/name`. `save` only writes the file — the caller then
/// runs the sync + Deploy ritual that carries the change to the keyboard.
struct SchemaSettings {
    /// One Schema row: its id, display name, and whether it is enabled.
    struct Entry: Equatable {
        let id: String
        let name: String
        var enabled: Bool
    }

    private let config: ConfigFolder
    private let directory: RimeDirectory

    init(config: ConfigFolder, directory: RimeDirectory) {
        self.config = config
        self.directory = directory
    }

    /// The Schema rows: enabled ones in schema_list order, then
    /// available-but-disabled ones sorted by id.
    var entries: [Entry] {
        let enabled = enabledIDs()
        let rows = enabled.map { Entry(id: $0, name: name(for: $0), enabled: true) }
        let disabled = availableIDs()
            .subtracting(enabled)
            .sorted()
            .map { Entry(id: $0, name: name(for: $0), enabled: false) }
        return rows + disabled
    }

    /// Writes the schema_list patch for `ids` (in order) into the Config
    /// Folder's `default.custom.yaml`, preserving every other line of the
    /// file — the last-write-wins rule is per file (ADR-0002), but settings
    /// owns only the schema_list block, not the user's other patches.
    func save(enabledIDs ids: [String]) throws {
        try FileManager.default.createDirectory(at: config.root, withIntermediateDirectories: true)
        let url = config.root.appendingPathComponent("default.custom.yaml")
        let block = ["  schema_list:"] + ids.map { "    - schema: \($0)" }
        let existing = (try? String(contentsOf: url, encoding: .utf8)) ?? ""
        var lines = existing.components(separatedBy: .newlines)
        // A trailing newline splits into a phantom empty line; dropping it
        // keeps re-joined output stable.
        if lines.last == "" { lines.removeLast() }

        guard let patchIndex = lines.firstIndex(where: { $0 == "patch:" }) else {
            lines += ["patch:"] + block
            try write(lines, to: url)
            return
        }
        // The patch mapping runs to the next top-level line or EOF.
        let patchEnd = lines[(patchIndex + 1)...].firstIndex(where: {
            !$0.isEmpty && !$0.hasPrefix(" ") && !$0.hasPrefix("\t")
        }) ?? lines.count
        guard let listIndex = lines[patchIndex..<patchEnd].firstIndex(where: isSchemaListKey) else {
            lines.insert(contentsOf: block, at: patchIndex + 1)
            try write(lines, to: url)
            return
        }
        // Replace the key line plus its contiguous item lines; anything else
        // (comments, a following key) stays put.
        var end = listIndex + 1
        while end < patchEnd, schemaListItem(lines[end]) != nil || lines[end].isEmpty {
            end += 1
        }
        lines.replaceSubrange(listIndex..<end, with: block)
        try write(lines, to: url)
    }

    /// The enabled Schema ids in schema_list order, parsed from the Config
    /// Folder's `default.custom.yaml`; empty when the file or the key is
    /// missing.
    func enabledIDs() -> [String] {
        let url = config.root.appendingPathComponent("default.custom.yaml")
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return [] }
        let lines = text.components(separatedBy: .newlines)
        guard let listIndex = lines.firstIndex(where: isSchemaListKey) else { return [] }
        var ids: [String] = []
        for line in lines[(listIndex + 1)...] {
            guard let id = schemaListItem(line) else {
                if line.isEmpty { continue }
                break
            }
            ids.append(id)
        }
        return ids
    }

    /// Ids of every top-level `*.schema.yaml` source on both sides.
    private func availableIDs() -> Set<String> {
        var ids = Set<String>()
        for directory in [config.root, self.directory.shared] {
            let names = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
            ids.formUnion(names.filter { $0.hasSuffix(".schema.yaml") }
                .map { String($0.dropLast(".schema.yaml".count)) })
        }
        return ids
    }

    /// The display name from the source's `schema/name` (Config Folder copy
    /// first, then shared), falling back to the id when no source parses.
    private func name(for id: String) -> String {
        let file = id + ".schema.yaml"
        for directory in [config.root, self.directory.shared] {
            let url = directory.appendingPathComponent(file)
            guard let text = try? String(contentsOf: url, encoding: .utf8) else { continue }
            if let name = schemaName(in: text) { return name }
        }
        return id
    }

    /// The `name` value inside the top-level `schema:` section, unquoted.
    private func schemaName(in text: String) -> String? {
        var inSchema = false
        for line in text.components(separatedBy: .newlines) {
            if line == "schema:" {
                inSchema = true
                continue
            }
            guard inSchema else { continue }
            if !line.isEmpty && !line.hasPrefix(" ") && !line.hasPrefix("\t") { return nil }
            guard let match = line.firstMatch(of: /^\s+name\s*:\s*(.+?)\s*$/) else { continue }
            var value = String(match.1)
            if value.count >= 2, value.first == value.last,
               value.first == "'" || value.first == "\"" {
                value = String(value.dropFirst().dropLast())
            }
            return value
        }
        return nil
    }

    private func isSchemaListKey(_ line: String) -> Bool {
        line.firstMatch(of: /^\s+schema_list\s*:\s*/) != nil
    }

    /// The id from a `- schema: <id>` item line; nil for any other line.
    private func schemaListItem(_ line: String) -> String? {
        line.firstMatch(of: /^\s+-\s*schema\s*:\s*([^\s#]+)/).map { String($0.1) }
    }

    private func write(_ lines: [String], to url: URL) throws {
        try (lines.joined(separator: "\n") + "\n").write(to: url, atomically: true, encoding: .utf8)
    }
}
