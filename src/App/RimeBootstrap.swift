import Foundation

/// The app-open ritual (ADR-0002): first launch seeds the Rime Directory and
/// the Config Folder and runs the first Deploy; every later launch syncs
/// Config Folder changes and Deploys only when something changed. Deploys
/// run on short-lived Engines that release the User Dictionary immediately
/// (ADR-0004). Last-good artifacts survive a failed Deploy, so typing keeps
/// working on the previous configuration.
enum RimeBootstrap {
    /// The first-launch stages, reported in order to `run`'s progress
    /// closure so onboarding can show live seed progress (ticket 18).
    /// `copyingBaseline` carries per-file counts (a determinate bar); the
    /// rest are indeterminate stages — librime's Deploy reports no progress.
    enum Stage {
        case copyingBaseline(copied: Int, total: Int)
        case preparingConfig
        case syncing
        case deploying
    }

    static func run(progress: ((Stage) -> Void)? = nil) -> String {
        guard let directory = RimeDirectory.appGroup() else {
            return "App Group container unavailable"
        }
        guard let baseline = Bundle.main.resourceURL?
            .appendingPathComponent("rime-baseline", isDirectory: true) else {
            return "Baseline data missing from bundle"
        }
        do {
            if !directory.isSeeded {
                return try firstLaunch(directory: directory, baseline: baseline, progress: progress)
            }
            return try syncAndDeploy(directory: directory, baseline: baseline)
        } catch {
            return "Prepare failed: \(error.localizedDescription)"
        }
    }

    /// The manual "Sync + Deploy" action — the same ritual as app open.
    static func syncAndDeployNow() -> String {
        guard let directory = RimeDirectory.appGroup(), directory.isSeeded else {
            return "Deploy failed: Rime data not ready"
        }
        guard let baseline = Bundle.main.resourceURL?
            .appendingPathComponent("rime-baseline", isDirectory: true) else {
            return "Deploy failed: baseline data missing from bundle"
        }
        do {
            return try syncAndDeploy(directory: directory, baseline: baseline)
        } catch {
            return "Deploy failed: \(error.localizedDescription)"
        }
    }

    private static func firstLaunch(directory: RimeDirectory, baseline: URL,
                                    progress: ((Stage) -> Void)?) throws -> String {
        let config = ConfigFolder.documents()
        try directory.seed(from: baseline) { copied, total in
            progress?(.copyingBaseline(copied: copied, total: total))
        }
        progress?(.preparingConfig)
        try config.seedIfNeeded(from: baseline)
        progress?(.syncing)
        _ = try config.sync(into: directory)
        progress?(.deploying)
        let engine = try Engine(directory: directory)
        defer { engine.shutdown() }
        try engine.deploy()
        try directory.markSeeded()
        return "Rime data ready (first-launch Deploy complete)"
    }

    private static func syncAndDeploy(directory: RimeDirectory, baseline: URL) throws -> String {
        let config = ConfigFolder.documents()
        try config.seedIfNeeded(from: baseline)
        let changed = try config.sync(into: directory)
        guard !changed.isEmpty else {
            return "Rime data ready (no config changes)"
        }
        let engine = try Engine(directory: directory)
        defer { engine.shutdown() }
        try engine.deploy()
        return "Synced \(changed.count) file(s): \(changed.joined(separator: ", ")) — Deploy complete"
    }
}
