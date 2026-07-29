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

    /// Copies the vendored baseline into `shared`, replacing any partial
    /// earlier copy, and ensures `user` exists. Does not mark the directory
    /// seeded — that happens only after the Deploy over this copy succeeds.
    func seed(from baseline: URL) throws {
        let fm = FileManager.default
        if fm.fileExists(atPath: shared.path) {
            try fm.removeItem(at: shared)
        }
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try fm.copyItem(at: baseline, to: shared)
        try fm.createDirectory(at: user, withIntermediateDirectories: true)
    }

    /// Records that seeding plus its first Deploy completed.
    func markSeeded() throws {
        try Data().write(to: seededMarker)
    }
}
