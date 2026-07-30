import Foundation

/// One Engine per test process, shared by every Engine test class: librime
/// hosts one live Engine per process, so no test may bootstrap its own. The
/// shared Engine runs against a scratch Rime Directory seeded from the
/// vendored baseline and is held for the process lifetime — never shut down.
enum TestEngine {
    /// The scratch Rime Directory the shared Engine runs against. Deploy
    /// tests mutate it but must restore it before finishing.
    static let directory = RimeDirectory(
        root: FileManager.default.temporaryDirectory
            .appendingPathComponent("coriander-engine-tests", isDirectory: true))

    static let shared: Result<Engine, Error> = {
        do {
            try? FileManager.default.removeItem(at: directory.root)
            let baseline = Bundle(for: TestBundleMarker.self).resourceURL!
                .appendingPathComponent("rime-baseline", isDirectory: true)
            try directory.seed(from: baseline)
            let engine = try Engine(directory: directory)
            try engine.deploy()
            return .success(engine)
        } catch {
            return .failure(error)
        }
    }()
}

/// Anchor for locating the test bundle's resources.
private final class TestBundleMarker {}
