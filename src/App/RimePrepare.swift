import Foundation
import Rime

/// Seeds the Rime Directory (App Group) from the vendored baseline and runs
/// the first Deploy, with per-stage timing and memory reporting. This is the
/// Container App's half of ticket 05's measurement (and the seed of tickets
/// 09/18): the keyboard reads deployed artifacts read-only, so Deploy must
/// happen here (ADR-0001).
enum RimePrepare {
    static func run(report: (String) -> Void) {
        guard let group = RimeMeter.groupURL else {
            report("FAIL: App Group container unavailable")
            return
        }
        guard let baseline = Bundle.main.resourceURL?.appendingPathComponent("rime-baseline") else {
            report("FAIL: rime-baseline not found in bundle")
            return
        }

        let shared = group.appendingPathComponent(RimeMeter.sharedDirName)
        let user = group.appendingPathComponent(RimeMeter.userDirName)
        let fm = FileManager.default

        // 1. seed (idempotent: replace shared side wholesale)
        let seedStart = Date()
        do {
            if fm.fileExists(atPath: shared.path) {
                try fm.removeItem(at: shared)
            }
            try fm.createDirectory(at: shared.deletingLastPathComponent(), withIntermediateDirectories: true)
            try fm.copyItem(at: baseline, to: shared)
            try fm.createDirectory(at: user, withIntermediateDirectories: true)
        } catch {
            report("FAIL seed: \(error.localizedDescription)")
            return
        }
        report(String(format: "seed: %.2fs, memory %.1f MB",
                      Date().timeIntervalSince(seedStart), RimeMeter.residentMemoryMB()))

        // 2. engine setup + initialize + deploy (start_maintenance)
        guard let api = rime_get_api()?.pointee else {
            report("FAIL: rime_get_api nil")
            return
        }
        let dir = strdup(shared.path)!
        let udir = strdup(user.path)!
        let codeName = strdup("coriander")!
        let distName = strdup("Coriander")!
        let distVersion = strdup("0.1")!
        let appName = strdup("coriander.prepare")!
        defer {
            free(dir); free(udir)
            free(codeName); free(distName); free(distVersion); free(appName)
        }

        var traits = RimeTraits()
        traits.data_size = Int32(MemoryLayout<RimeTraits>.size - MemoryLayout<Int32>.size)
        traits.shared_data_dir = UnsafePointer(dir)
        traits.user_data_dir = UnsafePointer(udir)
        traits.distribution_code_name = UnsafePointer(codeName)
        traits.distribution_name = UnsafePointer(distName)
        traits.distribution_version = UnsafePointer(distVersion)
        traits.app_name = UnsafePointer(appName)

        api.setup(&traits)
        let initStart = Date()
        api.initialize(&traits)
        report(String(format: "initialize: %.2fs, memory %.1f MB",
                      Date().timeIntervalSince(initStart), RimeMeter.residentMemoryMB()))

        let deployStart = Date()
        let ok = api.start_maintenance(1)
        guard ok != 0 else {
            report("deploy (start_maintenance): FAILED to start")
            api.finalize()
            return
        }
        api.join_maintenance_thread()  // blocks until the deployer finishes
        report(String(format: "deploy: %.2fs, memory %.1f MB",
                      Date().timeIntervalSince(deployStart), RimeMeter.residentMemoryMB()))

        api.finalize()
        report("prepare complete")
    }
}
