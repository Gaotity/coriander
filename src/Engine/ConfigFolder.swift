import Foundation

/// The Files-app-visible Config Folder (in the Container App's Documents):
/// the single source of truth for Rime configuration text (ADR-0002). The
/// one-way pipeline overlays it onto the Rime Directory's `user` side —
/// overwrite per file, never delete. Files edits and app-side writes (seed,
/// settings) to the same file resolve last-write-wins per file.
struct ConfigFolder: Equatable {
    /// Folder name visible in the Files app.
    static let folderName = "Rime Config"

    let root: URL

    /// The Config Folder inside the Container App's shared Documents.
    static func documents() -> ConfigFolder {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return ConfigFolder(root: documents.appendingPathComponent(folderName, isDirectory: true))
    }

    private var seededMarker: URL { root.appendingPathComponent(".seeded") }

    /// Populates the folder with the baseline's `default.custom.yaml` (the
    /// schema_list switch) on first launch only — a Files edit is never
    /// overwritten, and deleting the file does not resurrect it (the hidden
    /// marker, not the file, records the seed).
    @discardableResult
    func seedIfNeeded(from baseline: URL) throws -> Bool {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: seededMarker.path) else { return false }
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try fm.copyItem(at: baseline.appendingPathComponent("default.custom.yaml"),
                        to: root.appendingPathComponent("default.custom.yaml"))
        try Data().write(to: seededMarker)
        return true
    }

    /// Overlays every file (recursively) onto `directory.user`, copying only
    /// content that differs. Returns the relative paths actually copied; the
    /// caller Deploys only when this is non-empty. Never deletes from the
    /// Rime Directory. Hidden files and directories (e.g. `.DS_Store`,
    /// `.git`) are skipped.
    @discardableResult
    func sync(into directory: RimeDirectory) throws -> [String] {
        let fm = FileManager.default
        guard fm.fileExists(atPath: root.path) else { return [] }
        // The enumerator yields canonical paths while `root` may contain a
        // symlink (/var vs /private/var on device) — resolve both before
        // string arithmetic, or relative paths come out mangled.
        let rootPath = root.resolvingSymlinksInPath().path
        var changed: [String] = []
        let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: [.isRegularFileKey],
                                       options: [.skipsHiddenFiles])
        while let file = enumerator?.nextObject() as? URL {
            guard try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
            let relative = String(file.resolvingSymlinksInPath().path.dropFirst(rootPath.count + 1))
            let target = directory.user.appendingPathComponent(relative)
            guard try contentsDiffer(file, target) else { continue }
            try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            if fm.fileExists(atPath: target.path) {
                // A failed copy loses the previous user-side file, but the
                // next sync's content check heals it.
                try fm.removeItem(at: target)
            }
            try fm.copyItem(at: file, to: target)
            changed.append(relative)
        }
        return changed.sorted()
    }

    private func contentsDiffer(_ source: URL, _ target: URL) throws -> Bool {
        guard FileManager.default.fileExists(atPath: target.path) else { return true }
        return try Data(contentsOf: source) != Data(contentsOf: target)
    }
}
