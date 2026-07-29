import Foundation

/// One Engine per test process, shared by every Engine test class: librime
/// cannot finalize and re-initialize within a process, so no test may
/// bootstrap (or shut down) its own Engine. The shared Engine runs against a
/// scratch Rime Directory seeded from the vendored baseline and is held for
/// the process lifetime — never finalized.
enum TestEngine {
    static let shared: Result<Engine, Error> = {
        do {
            let root = FileManager.default.temporaryDirectory
                .appendingPathComponent("coriander-engine-tests", isDirectory: true)
            try? FileManager.default.removeItem(at: root)
            let directory = RimeDirectory(root: root)
            let baseline = Bundle(for: TestBundleMarker.self).resourceURL!
                .appendingPathComponent("rime-baseline", isDirectory: true)
            try directory.seed(from: baseline)
            return .success(try Engine(directory: directory, deploy: true))
        } catch {
            return .failure(error)
        }
    }()
}

/// Anchor for locating the test bundle's resources.
private final class TestBundleMarker {}
