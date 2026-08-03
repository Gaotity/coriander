import XCTest

/// The per-file seed progress (ticket 18): the callback fires once per
/// baseline file with strictly increasing counts ending at the total, and
/// the resulting `shared` side holds every baseline file — including
/// nested ones (opencc/). The callback-free path is exercised by every
/// other suite that seeds (TestEngine, LifecycleTests).
final class SeedProgressTests: XCTestCase {
    func testSeedReportsProgressPerFileAndCopiesEverything() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("coriander-seed-progress/\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = RimeDirectory(root: root)
        let baseline = Bundle(for: SeedProgressTests.self).resourceURL!
            .appendingPathComponent("rime-baseline", isDirectory: true)

        var reports: [(copied: Int, total: Int)] = []
        try directory.seed(from: baseline) { copied, total in
            reports.append((copied, total))
        }

        XCTAssertFalse(reports.isEmpty)
        XCTAssertEqual(reports.map(\.copied), Array(1...reports.count),
                       "counts must increase one file at a time")
        XCTAssertEqual(reports.last?.copied, reports.last?.total)

        // Every baseline regular file landed under `shared` at its
        // relative path — the total matches the file count exactly.
        let fm = FileManager.default
        let basePath = baseline.resolvingSymlinksInPath().path
        let enumerator = fm.enumerator(at: baseline, includingPropertiesForKeys: [.isRegularFileKey])
        var baselineFiles = 0
        while let file = enumerator?.nextObject() as? URL {
            guard try file.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
            baselineFiles += 1
            let relative = String(file.resolvingSymlinksInPath().path.dropFirst(basePath.count + 1))
            XCTAssertTrue(fm.fileExists(atPath: directory.shared.appendingPathComponent(relative).path),
                          "missing seeded file: \(relative)")
        }
        XCTAssertEqual(reports.last?.total, baselineFiles)
        // A nested file proves subdirectory copies work (opencc/ in the baseline).
        XCTAssertTrue(fm.fileExists(atPath: directory.shared
            .appendingPathComponent("opencc/s2t.json").path))
        // Seeding alone never marks the directory seeded.
        XCTAssertFalse(directory.isSeeded)
    }
}
