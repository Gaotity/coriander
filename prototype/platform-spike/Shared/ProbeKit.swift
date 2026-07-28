// PROTOTYPE — Ticket 01 platform validation spike. Throwaway; never merge to main.
import Foundation

// Shared measurement helpers for the platform spike. Used by both the app and
// the keyboard extension targets.
enum ProbeKit {
    static let groupID = "group.com.gaotity.coriander.spike"
    static let launchTimestamp = Date()

    static var groupURL: URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: groupID)
    }

    /// Resident memory of the current process, in MB.
    static func residentMemoryMB() -> Double {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return -1 }
        return Double(info.resident_size) / 1_048_576
    }

    struct ProbeResult: CustomStringConvertible {
        let name: String
        let ok: Bool
        let detail: String
        var description: String { "[\(ok ? "OK" : "FAIL")] \(name): \(detail)" }
    }

    /// Write + read + delete a small file in the App Group container.
    static func probeGroupWrite() -> ProbeResult {
        guard let dir = groupURL else {
            return ProbeResult(name: "group-write", ok: false, detail: "containerURL returned nil")
        }
        let file = dir.appendingPathComponent("probe-\(UUID().uuidString).tmp")
        do {
            try "spike".write(to: file, atomically: true, encoding: .utf8)
            let back = try String(contentsOf: file, encoding: .utf8)
            try FileManager.default.removeItem(at: file)
            return ProbeResult(name: "group-write", ok: back == "spike", detail: "wrote/read/deleted in \(dir.path)")
        } catch {
            return ProbeResult(name: "group-write", ok: false, detail: error.localizedDescription)
        }
    }

    /// Read-only probe: can we see files the other process wrote?
    static func probeGroupRead() -> ProbeResult {
        guard let dir = groupURL else {
            return ProbeResult(name: "group-read", ok: false, detail: "containerURL returned nil")
        }
        do {
            let items = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            return ProbeResult(name: "group-read", ok: true, detail: "\(items.count) item(s): \(items.prefix(5).joined(separator: ", "))")
        } catch {
            return ProbeResult(name: "group-read", ok: false, detail: error.localizedDescription)
        }
    }

    /// Append a result line to the shared log (best effort — may fail for the
    /// keyboard without Full Access, which is itself a measurement).
    @discardableResult
    static func logToGroup(_ line: String) -> ProbeResult {
        guard let dir = groupURL else {
            return ProbeResult(name: "group-log", ok: false, detail: "containerURL returned nil")
        }
        let file = dir.appendingPathComponent("spike-results.log")
        let stamped = "\(ISO8601DateFormatter().string(from: Date())) \(line)\n"
        do {
            if FileManager.default.fileExists(atPath: file.path) {
                let handle = try FileHandle(forWritingTo: file)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: Array(stamped.utf8))
            } else {
                try stamped.write(to: file, atomically: true, encoding: .utf8)
            }
            return ProbeResult(name: "group-log", ok: true, detail: line)
        } catch {
            return ProbeResult(name: "group-log", ok: false, detail: error.localizedDescription)
        }
    }

    static func readGroupLog() -> String {
        guard let file = groupURL?.appendingPathComponent("spike-results.log"),
              let text = try? String(contentsOf: file, encoding: .utf8) else {
            return "(no shared log yet)"
        }
        return text
    }

    /// Simulate the baseline seed: write ~40 MB across many small files into
    /// the group container, then delete. Returns duration in seconds.
    static func seedBenchmark(totalMB: Int = 40, fileCount: Int = 200) -> ProbeResult {
        guard let dir = groupURL else {
            return ProbeResult(name: "seed-benchmark", ok: false, detail: "containerURL returned nil")
        }
        let seedDir = dir.appendingPathComponent("seed-benchmark-tmp")
        let chunk = Data((0..<(totalMB * 1_048_576 / fileCount)).map { UInt8($0 & 0xFF) })
        let start = Date()
        do {
            try FileManager.default.createDirectory(at: seedDir, withIntermediateDirectories: true)
            for i in 0..<fileCount {
                try chunk.write(to: seedDir.appendingPathComponent("f\(i).bin"))
            }
            let duration = Date().timeIntervalSince(start)
            try FileManager.default.removeItem(at: seedDir)
            let detail = String(format: "%d MB / %d files in %.2fs (%.1f MB/s)", totalMB, fileCount, duration, Double(totalMB) / duration)
            return ProbeResult(name: "seed-benchmark", ok: true, detail: detail)
        } catch {
            return ProbeResult(name: "seed-benchmark", ok: false, detail: error.localizedDescription)
        }
    }
}
