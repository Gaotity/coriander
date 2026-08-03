import Foundation

/// The Keyboard Extension's process-wide Engine — one per process, as the
/// Engine itself enforces. It only runs input Sessions against the
/// already-Deployed Rime Directory (Deploy is the Container App's job,
/// ADR-0001). The User Dictionary persists only when the process can write
/// the user side — with Full Access (ADR-0003); without it librime
/// degrades read-only on its own (probed: learning silently off, no
/// crash), so nothing here needs gating. When the directory is not seeded
/// yet the keyboard shows a setup hint instead of the typing UI.
enum KeyboardEngine {
    static let shared: Result<Engine, Error> = {
        do {
            guard let directory = RimeDirectory.appGroup(), directory.isSeeded else {
                return .failure(SetupError.rimeDirectoryNotSeeded)
            }
            return .success(try Engine(directory: directory))
        } catch {
            return .failure(error)
        }
    }()

    /// Build time of the artifacts the current Session loaded. Process-wide
    /// on purpose: controller instances come and go while the Session lives,
    /// so snapshotting this in a controller would mask staleness.
    static var sessionBuiltAt: Date?

    enum SetupError: Error {
        /// The Container App has not completed its first-launch seed + Deploy.
        case rimeDirectoryNotSeeded
    }
}
