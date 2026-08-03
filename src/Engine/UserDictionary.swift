import Foundation

/// Export, restore, and clear for the User Dictionary (ticket 15) —
/// Container App only, per the spec's Export decision: persistent user state
/// (above all the User Dictionary) packaged into ONE archive in
/// Files-visible storage; configuration is excluded (the Config Folder is
/// already visible), baseline data and compiled artifacts too (reproducible).
///
/// The archive holds one `<dict>.userdb.txt` TSV dump per User Dictionary —
/// librime's own portable learning format (levers `export_user_dict`),
/// probed as the only management primitive that takes explicit paths:
/// `backup_user_dict` writes to a CWD-relative sync dir, `restore_user_dict`
/// needs that snapshot format, `sync_user_data` fails outside a maintenance
/// context. Restore merges the dumps back (`import_user_dict`); after a
/// clear that is a full round-trip of the learned vocabulary.
///
/// Single-writer rule: export and restore run on a short-lived Engine that
/// never opens a Session (ADR-0004) — a Session holds the dictionary's
/// LevelDB lock (probed), so these ops serialize behind any live one; if the
/// keyboard holds the lock, the levers calls fail cleanly and the error
/// surfaces to the user instead of touching the files. Clear is a file-level
/// removal of the `*.userdb` directories: under a live writer POSIX unlink
/// semantics keep the holder's handles valid (probed) — it keeps typing on
/// its unlinked copy, its last writes vanish with it, and the next Engine
/// starts over empty. No crash, no partial dictionary, no corruption.
enum UserDictionary {
    /// File name prefix for export archives in Files-visible storage.
    static let archivePrefix = "coriander-userdict"

    enum ManagementError: Error {
        /// No User Dictionary exists yet — nothing has been learned.
        case nothingToExport
        /// The archive holds no `<dict>.userdb.txt` entries — not one of ours.
        case noDictionariesInArchive
    }

    /// Exports every User Dictionary into one zip archive placed in
    /// `folder` (the Container App's Files-visible Documents), returning the
    /// archive's URL. `archiveName` defaults to a timestamped name.
    @discardableResult
    static func export(directory: RimeDirectory, into folder: URL,
                       archiveName: String = defaultArchiveName()) throws -> URL {
        let names = directory.userDictionaryNames
        guard !names.isEmpty else { throw ManagementError.nothingToExport }
        let staging = try makeStaging()
        defer { try? FileManager.default.removeItem(at: staging) }

        let engine = try Engine(directory: directory)
        defer { engine.shutdown() }
        var entries: [ZipArchive.Entry] = []
        for name in names {
            let dump = staging.appendingPathComponent("\(name).userdb.txt")
            try engine.exportUserDictionary(name, to: dump)
            entries.append(ZipArchive.Entry(name: "\(name).userdb.txt",
                                            data: try Data(contentsOf: dump)))
        }

        let fm = FileManager.default
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        let archive = folder.appendingPathComponent(archiveName)
        if fm.fileExists(atPath: archive.path) {
            try fm.removeItem(at: archive)
        }
        try ZipArchive.write(entries: entries, to: archive)
        return archive
    }

    /// Restores an archive written by `export`: merges every
    /// `<dict>.userdb.txt` entry back into its User Dictionary, returning
    /// the restored dictionary names. Merge semantics (librime's only
    /// explicit-path restore primitive): entries learned since the export
    /// survive. Full validated Import with rollback is ticket 21.
    @discardableResult
    static func restore(archive: URL, into directory: RimeDirectory) throws -> [String] {
        let entries = try ZipArchive.readEntries(from: archive)
            .filter { $0.name.hasSuffix(".userdb.txt") }
        guard !entries.isEmpty else { throw ManagementError.noDictionariesInArchive }
        let staging = try makeStaging()
        defer { try? FileManager.default.removeItem(at: staging) }

        let engine = try Engine(directory: directory)
        defer { engine.shutdown() }
        var restored: [String] = []
        for entry in entries {
            let name = String(entry.name.dropLast(".userdb.txt".count))
            let dump = staging.appendingPathComponent(entry.name)
            try entry.data.write(to: dump)
            try engine.importUserDictionary(name, from: dump)
            restored.append(name)
        }
        return restored.sorted()
    }

    /// Clears every User Dictionary by removing its `*.userdb` directory,
    /// returning the cleared names. Safe against a live writer (see the
    /// type comment); the keyboard keeps typing and starts over empty on
    /// its next Engine.
    @discardableResult
    static func clear(directory: RimeDirectory) throws -> [String] {
        let fm = FileManager.default
        var cleared: [String] = []
        for name in directory.userDictionaryNames {
            try fm.removeItem(at: directory.user
                .appendingPathComponent("\(name).userdb", isDirectory: true))
            cleared.append(name)
        }
        return cleared
    }

    /// `coriander-userdict-<yyyyMMdd-HHmmss>.zip` — timestamped, so repeated
    /// exports do not replace older backups (same-second repeats do, by
    /// name — a benign edge the user creates only deliberately).
    static func defaultArchiveName(now: Date = Date()) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return "\(archivePrefix)-\(formatter.string(from: now)).zip"
    }

    private static func makeStaging() throws -> URL {
        let staging = FileManager.default.temporaryDirectory
            .appendingPathComponent("coriander-userdict-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: staging, withIntermediateDirectories: true)
        return staging
    }
}

extension UserDictionary.ManagementError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .nothingToExport:
            return "no learned words to export yet"
        case .noDictionariesInArchive:
            return "not a Coriander User Dictionary archive"
        }
    }
}
