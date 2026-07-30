import Foundation

/// The Keyboard Extension's process-wide Engine — one per process, as the
/// Engine itself enforces. Runs read-only against the already-Deployed Rime
/// Directory (Deploy is the Container App's job, ADR-0001). When the
/// directory is not seeded yet the keyboard shows a setup hint instead of
/// the typing UI.
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

    enum SetupError: Error {
        /// The Container App has not completed its first-launch seed + Deploy.
        case rimeDirectoryNotSeeded
    }
}
