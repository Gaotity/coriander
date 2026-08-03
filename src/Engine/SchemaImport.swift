import Foundation

/// Import (ticket 21), Container App only: merge external Rime files into
/// the Config Folder — overlay only, never deletes — validate them, and roll
/// back entirely on failure. Sources are single or multiple loose `*.yaml`
/// files plus `*.zip` archives in the one format ZipArchive reads (STORE
/// entries, flat names); archives can also carry non-yaml payload files a
/// Schema may reference (table data, opencc configs).
///
/// Validation runs in two layers because a Deploy alone cannot be trusted
/// (ticket 09 probe): librime silently ignores a broken custom patch, so
/// every imported yaml is syntax-checked in memory (the config API's
/// `config_load_string`) BEFORE anything is written; only schema-source
/// compile failures make the post-write Deploy fail, and those surface
/// through the Engine's failedSchemas check.
///
/// Rollback restores the pre-Import state of every affected path on BOTH
/// sides — the Config Folder byte-identical, the synced copies in the Rime
/// Directory too — then rebuilds the artifacts the partial Deploy may have
/// baked imported content into, so typing is byte-for-byte the previous
/// behavior. The affected artifacts are reproducible by definition (they
/// compile from the restored sources), so they are deleted and rebuilt
/// rather than snapshotted.
enum SchemaImport {
    /// One offered file: the entry name it should land under in the Config
    /// Folder, plus a local readable URL (the app layer stages picker and
    /// share-sheet URLs into its sandbox first).
    struct Source {
        let name: String
        let url: URL
    }

    /// What a successful Import changed in the Config Folder.
    struct Report: Equatable {
        /// Entry names that landed as new files.
        let added: [String]
        /// Entry names that overwrote a different prior content.
        let overwritten: [String]
    }

    enum ImportError: Error {
        /// No importable file was offered (empty offer or empty archive).
        case nothingToImport
        /// A loose file is not yaml — loose Imports are yaml-only.
        case unsupportedFile(String)
        /// A file or archive entry name is not a plain flat file name.
        case unsafeName(String)
        /// The named archive is not a zip ZipArchive reads (compressed,
        /// traversal, garbage).
        case unreadableArchive(String, detail: String)
        /// These yaml files failed syntax validation (pre-Deploy).
        case invalidYaml([String])
        /// The post-Deploy compile check failed; everything was rolled back.
        case deployFailed(String)
    }

    /// One staged import payload: a flat entry name and its bytes.
    private struct Entry {
        let name: String
        let data: Data
    }

    /// The pre-Import state of one path: its prior bytes, or nil when the
    /// path did not exist.
    private struct PathSnapshot {
        let url: URL
        let prior: Data?
    }

    /// Merges the offered files into the Config Folder and validates them
    /// with a Deploy; on any failure everything is rolled back and the
    /// error rethrown. Runs its Deploys on short-lived Engines (ADR-0004),
    /// never with an open Session.
    @discardableResult
    static func importFiles(_ sources: [Source], into config: ConfigFolder,
                            directory: RimeDirectory) throws -> Report {
        let entries = try assembleEntries(from: sources)
        let fm = FileManager.default

        let engine = try Engine(directory: directory)
        // Pre-Deploy validation — nothing has been written yet, so a
        // rejection here leaves both sides untouched by construction.
        let broken = entries
            .filter { isYaml($0.name) && !engine.validateYaml(validationText(of: $0)) }
            .map(\.name)
        guard broken.isEmpty else {
            engine.shutdown()
            throw ImportError.invalidYaml(broken.sorted())
        }

        // Snapshot every affected path on both sides before writing.
        let configSnapshots = snapshot(entries.map { config.root.appendingPathComponent($0.name) })
        let userSnapshots = snapshot(entries.map { directory.user.appendingPathComponent($0.name) })
        let deployedIDs = deployedSchemaIDs(userSide: directory.user)

        do {
            try fm.createDirectory(at: config.root, withIntermediateDirectories: true)
            for entry in entries {
                let target = config.root.appendingPathComponent(entry.name)
                // Identical content is a no-op: repeated Imports stay cheap
                // and never touch mtimes (which librime's rebuild trigger
                // compares).
                guard (try? Data(contentsOf: target)) != entry.data else { continue }
                try entry.data.write(to: target, options: .atomic)
            }
            let changed = try config.sync(into: directory)
            if !changed.isEmpty {
                try engine.deploy()
            }
            engine.shutdown()
        } catch {
            engine.shutdown()
            restore(configSnapshots)
            restore(userSnapshots)
            purgeArtifacts(for: entries.map(\.name), deployedIDs: deployedIDs,
                           userSide: directory.user)
            // Rebuild from the restored sources so typing returns to the
            // pre-Import behavior. Best effort: the restored state Deployed
            // before, and a failure here heals on the next sync + Deploy —
            // the Import error stays the one that matters.
            if let fresh = try? Engine(directory: directory) {
                try? fresh.deploy()
                fresh.shutdown()
            }
            if let deployError = error as? Engine.DeployError {
                throw ImportError.deployFailed(deployError.localizedDescription)
            }
            throw error
        }

        var added: [String] = []
        var overwritten: [String] = []
        for (entry, snap) in zip(entries, configSnapshots) {
            guard snap.prior != entry.data else { continue }
            if snap.prior == nil {
                added.append(entry.name)
            } else {
                overwritten.append(entry.name)
            }
        }
        return Report(added: added.sorted(), overwritten: overwritten.sorted())
    }

    /// Flattens the offer into entries: loose yaml files as themselves, zip
    /// archives through ZipArchive's reader (which rejects compressed,
    /// traversal, and garbage archives). Duplicate names resolve
    /// last-offer-wins, mirroring the per-file overlay rule.
    private static func assembleEntries(from sources: [Source]) throws -> [Entry] {
        var byName: [String: Data] = [:]
        var order: [String] = []
        for source in sources {
            guard isSafeName(source.name) else { throw ImportError.unsafeName(source.name) }
            if source.name.hasSuffix(".zip") {
                let archiveEntries: [ZipArchive.Entry]
                do {
                    archiveEntries = try ZipArchive.readEntries(from: source.url)
                } catch ZipArchive.ZipError.unsafeName(let entry) {
                    throw ImportError.unreadableArchive(source.name,
                                                        detail: "unsafe entry name: \(entry)")
                } catch ZipArchive.ZipError.malformed(let why) {
                    throw ImportError.unreadableArchive(source.name, detail: why)
                }
                for entry in archiveEntries {
                    if byName[entry.name] == nil { order.append(entry.name) }
                    byName[entry.name] = entry.data
                }
            } else if isYaml(source.name) {
                if byName[source.name] == nil { order.append(source.name) }
                byName[source.name] = try Data(contentsOf: source.url)
            } else {
                throw ImportError.unsupportedFile(source.name)
            }
        }
        guard !order.isEmpty else { throw ImportError.nothingToImport }
        return order.compactMap { name in byName[name].map { Entry(name: name, data: $0) } }
    }

    /// The yaml text to validate for an entry. `*.dict.yaml` is yaml only up
    /// to the header-terminating `...` line — the table body below is TSV
    /// and must not be parsed.
    private static func validationText(of entry: Entry) -> String {
        let text = String(decoding: entry.data, as: UTF8.self)
        guard entry.name.hasSuffix(".dict.yaml") else { return text }
        let lines = text.components(separatedBy: .newlines)
        guard let end = lines.firstIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == "..."
        }) else { return text }
        return lines[...end].joined(separator: "\n")
    }

    private static func isYaml(_ name: String) -> Bool {
        name.hasSuffix(".yaml") || name.hasSuffix(".yml")
    }

    /// A plain flat file name — the same rule ZipArchive enforces on archive
    /// entries, applied to loose offers too: no dotfiles, no separators.
    private static func isSafeName(_ name: String) -> Bool {
        !name.isEmpty && !name.hasPrefix(".")
            && !name.contains("/") && !name.contains("\\") && !name.contains(":")
    }

    private static func snapshot(_ urls: [URL]) -> [PathSnapshot] {
        urls.map { PathSnapshot(url: $0, prior: try? Data(contentsOf: $0)) }
    }

    private static func restore(_ snapshots: [PathSnapshot]) {
        for snap in snapshots {
            if let prior = snap.prior {
                try? prior.write(to: snap.url, options: .atomic)
            } else {
                try? FileManager.default.removeItem(at: snap.url)
            }
        }
    }

    /// Deletes the build artifacts a partial Deploy may have baked imported
    /// content into, forcing the rollback Deploy to rebuild them from the
    /// restored sources (librime's freshness check compares second-precision
    /// mtimes, so content restored over a fresh artifact could otherwise be
    /// skipped). `build/default.yaml` always goes — the deployed schema_list
    /// must again reflect the restored defaults. Imported schemas, their
    /// custom patches, and — since a dictionary or default config can feed
    /// every Schema — for those the whole previously deployed set go too.
    /// All of it is reproducible by construction.
    private static func purgeArtifacts(for entryNames: [String], deployedIDs: [String],
                                       userSide: URL) {
        let fm = FileManager.default
        let build = userSide.appendingPathComponent("build", isDirectory: true)
        var purge: Set<String> = ["default.yaml"]
        var rebuildDeployedSet = false
        for name in entryNames {
            if name == "default.yaml" || name == "default.custom.yaml" {
                rebuildDeployedSet = true
            }
            for suffix in [".schema.yaml", ".custom.yaml"] where name.hasSuffix(suffix) {
                purge.insert(String(name.dropLast(suffix.count)) + ".schema.yaml")
            }
            if name.hasSuffix(".dict.yaml") {
                rebuildDeployedSet = true
                let stem = String(name.dropLast(".dict.yaml".count))
                let files = (try? fm.contentsOfDirectory(atPath: build.path)) ?? []
                purge.formUnion(files.filter { $0.hasPrefix(stem) })
            }
        }
        if rebuildDeployedSet {
            purge.formUnion(deployedIDs.map { $0 + ".schema.yaml" })
        }
        for file in purge {
            try? fm.removeItem(at: build.appendingPathComponent(file))
        }
    }

    /// The schema_list ids of the currently deployed default config
    /// (`build/default.yaml`) — the set whose artifacts a dictionary or
    /// defaults rollback must rebuild; empty when it cannot be read.
    private static func deployedSchemaIDs(userSide: URL) -> [String] {
        let deployed = userSide.appendingPathComponent("build/default.yaml")
        guard let text = try? String(contentsOf: deployed, encoding: .utf8) else { return [] }
        let lines = text.components(separatedBy: .newlines)
        guard let listIndex = lines.firstIndex(where: { $0.hasPrefix("schema_list:") }) else { return [] }
        var ids: [String] = []
        for line in lines[(listIndex + 1)...] {
            guard let match = line.firstMatch(of: /^\s+-\s*schema\s*:\s*([^\s#]+)/) else {
                if line.isEmpty { continue }
                break
            }
            ids.append(String(match.1))
        }
        return ids
    }
}

extension SchemaImport.ImportError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .nothingToImport:
            return "nothing importable was offered"
        case .unsupportedFile(let name):
            return "\(name) is not a yaml file — import yaml files or a zip archive"
        case .unsafeName(let name):
            return "\(name) is not a usable file name"
        case .unreadableArchive(let name, let detail):
            return "\(name) is not an importable archive (\(detail))"
        case .invalidYaml(let names):
            return "invalid YAML in: \(names.joined(separator: ", "))"
        case .deployFailed(let detail):
            return "the imported configuration did not Deploy: \(detail)"
        }
    }
}
