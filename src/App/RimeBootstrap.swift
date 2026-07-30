import Foundation

/// First-launch bootstrap for the Container App: seed the Rime Directory
/// from the vendored baseline and run one Deploy, then shut the Engine down
/// so it releases the User Dictionary for the Keyboard Extension (only one
/// Engine holds it open at a time). The marker written after a successful
/// Deploy makes the second launch skip everything.
enum RimeBootstrap {
    static func run() -> String {
        guard let directory = RimeDirectory.appGroup() else {
            return "App Group container unavailable"
        }
        guard !directory.isSeeded else {
            return "Rime data ready"
        }
        guard let baseline = Bundle.main.resourceURL?
            .appendingPathComponent("rime-baseline", isDirectory: true) else {
            return "Baseline data missing from bundle"
        }
        do {
            try directory.seed(from: baseline)
            let engine = try Engine(directory: directory)
            defer { engine.shutdown() }
            try engine.deploy()
            try directory.markSeeded()
            return "Rime data ready (first-launch Deploy complete)"
        } catch {
            return "Prepare failed: \(error.localizedDescription)"
        }
    }

    /// On-demand Deploy (ticket 09): a short-lived Engine performs it and
    /// shuts down immediately, releasing the User Dictionary for the
    /// Keyboard Extension. Last-good artifacts survive a failed Deploy, so
    /// typing keeps working on the previous configuration.
    static func deployNow() -> String {
        guard let directory = RimeDirectory.appGroup(), directory.isSeeded else {
            return "Deploy failed: Rime data not ready"
        }
        do {
            let engine = try Engine(directory: directory)
            defer { engine.shutdown() }
            try engine.deploy()
            return "Deploy complete"
        } catch {
            return "Deploy failed: \(error.localizedDescription)"
        }
    }
}
