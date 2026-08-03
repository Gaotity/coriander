import Foundation

/// Layout and first-launch seeding of the Rime Directory: `shared` holds the
/// seeded baseline, `user` holds Deployed artifacts and the User Dictionary.
/// The Container App seeds; both processes point their Engine at the same
/// directory.
struct RimeDirectory: Equatable {
    static let groupID = "group.com.gaotity.coriander"

    /// Root of the Rime Directory (the `rime` folder).
    let root: URL

    var shared: URL { root.appendingPathComponent("shared", isDirectory: true) }
    var user: URL { root.appendingPathComponent("user", isDirectory: true) }

    /// The Rime Directory inside the App Group container.
    static func appGroup() -> RimeDirectory? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupID)
            .map { RimeDirectory(root: $0.appendingPathComponent("rime", isDirectory: true)) }
    }

    private var seededMarker: URL { root.appendingPathComponent(".seeded") }

    /// True once a baseline copy completed a successful Deploy. Second launch
    /// skips the seed entirely (ticket 07 acceptance).
    var isSeeded: Bool {
        FileManager.default.fileExists(atPath: seededMarker.path)
    }

    /// Whether this process can write the user side of the Rime Directory —
    /// the Keyboard Extension can only with Full Access (ticket 01, measured
    /// on device). Probed with a real write: no API reports the sandbox
    /// denial, it surfaces only on write. When false the Engine runs
    /// read-only: librime itself degrades (userdb open fails, learning
    /// silently off, no crash — probed), so this is a report, not a switch.
    var canWriteUser: Bool {
        let probe = user.appendingPathComponent(".\(UUID().uuidString)")
        do {
            try Data().write(to: probe)
        } catch {
            return false
        }
        try? FileManager.default.removeItem(at: probe)
        return true
    }

    /// Names of the User Dictionaries on the user side — the `*.userdb`
    /// LevelDB directories (e.g. ["luna_pinyin"]). A file scan; needs no
    /// Engine. Probed: this is the complete persistent-user-state set —
    /// `build/` is reproducible artifacts, `user.yaml`/`installation.yaml`
    /// are deployment bookkeeping.
    var userDictionaryNames: [String] {
        let entries = (try? FileManager.default.contentsOfDirectory(atPath: user.path)) ?? []
        return entries
            .filter { $0.hasSuffix(".userdb") }
            .map { String($0.dropLast(".userdb".count)) }
            .sorted()
    }

    /// When the last Deploy completed, per `user.yaml`'s `var/last_build_time`
    /// (written by librime's WorkspaceUpdate). The keyboard watches this to
    /// pick up artifacts Deployed by the Container App while it was warm.
    var lastDeployTime: Date? {
        let userYaml = user.appendingPathComponent("user.yaml")
        guard let text = try? String(contentsOf: userYaml, encoding: .utf8) else { return nil }
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.hasPrefix("last_build_time:") else { continue }
            let value = trimmed.dropFirst("last_build_time:".count)
                .trimmingCharacters(in: .whitespaces)
            return Int(value).map { Date(timeIntervalSince1970: TimeInterval($0)) }
        }
        return nil
    }

    /// Copies the vendored baseline into `shared`, replacing any partial
    /// earlier copy, and ensures `user` exists. Does not mark the directory
    /// seeded — that happens only after the Deploy over this copy succeeds.
    /// Copies file by file and reports `progress(copied, total)` after each
    /// file so first launch can show real seed progress (ticket 18).
    func seed(from baseline: URL, progress: ((Int, Int) -> Void)? = nil) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: shared.path) {
            try fm.removeItem(at: shared)
        }
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try fm.createDirectory(at: shared, withIntermediateDirectories: true)
        try fm.createDirectory(at: user, withIntermediateDirectories: true)

        // Resolve symlinks on both sides before relative-path arithmetic,
        // as in ConfigFolder.sync (/var vs /private/var on device).
        let basePath = baseline.resolvingSymlinksInPath().path
        var files: [URL] = []
        let enumerator = fm.enumerator(at: baseline, includingPropertiesForKeys: [.isRegularFileKey])
        while let file = enumerator?.nextObject() as? URL {
            guard try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
            files.append(file)
        }
        for (copied, file) in files.enumerated() {
            let relative = String(file.resolvingSymlinksInPath().path.dropFirst(basePath.count + 1))
            let target = shared.appendingPathComponent(relative)
            try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: file, to: target)
            progress?(copied + 1, files.count)
        }
    }

    /// Records that seeding plus its first Deploy completed.
    func markSeeded() throws {
        try Data().write(to: seededMarker)
    }
}
