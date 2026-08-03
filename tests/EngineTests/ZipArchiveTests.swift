import XCTest

/// The zip facility behind Export (ticket 15). The golden-bytes test pins
/// the exact archive layout against an independently computed reference (the
/// same bytes python's zipfile accepts), so format regressions cannot hide
/// behind our own reader.
final class ZipArchiveTests: XCTestCase {
    /// One stored entry "a.txt" containing "AB", fixed DOS timestamp
    /// 1980-01-01 — byte-for-byte the reference layout.
    func testGoldenBytes() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("coriander-zip-golden-\(UUID().uuidString).zip")
        defer { try? FileManager.default.removeItem(at: url) }
        try ZipArchive.write(entries: [ZipArchive.Entry(name: "a.txt", data: Data("AB".utf8))],
                             to: url)
        let expected = "504b030414000000000000002100074c6930020000000200000005000000"
            + "612e7478744142504b0102140014000000000000002100074c6930020000"
            + "0002000000050000000000000000000000000000000000612e747874504b"
            + "0506000000000100010033000000250000000000"
        XCTAssertEqual(try Data(contentsOf: url).hexString, expected)
    }

    /// Round-trip: several entries, one empty, one with UTF-8 content.
    func testWriteThenReadReturnsSameEntries() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("coriander-zip-roundtrip-\(UUID().uuidString).zip")
        defer { try? FileManager.default.removeItem(at: url) }
        let entries = [
            ZipArchive.Entry(name: "luna_pinyin.userdb.txt", data: Data("諾吐\tnuo tu\tc=3".utf8)),
            ZipArchive.Entry(name: "empty.userdb.txt", data: Data()),
        ]
        try ZipArchive.write(entries: entries, to: url)
        let back = try ZipArchive.readEntries(from: url)
        XCTAssertEqual(back.map(\.name), entries.map(\.name))
        XCTAssertEqual(back.map(\.data), entries.map(\.data))
    }

    /// A compressed (deflated) entry is rejected — this reader exists for
    /// the app's own archives, not arbitrary zips. The fixture is a real
    /// deflate zip produced by python's zipfile (verified byte-identical
    /// against it); the assertion pins the exact rejection branch.
    func testCompressedEntryIsRejected() throws {
        let hex = "504b0304140000000800cc6d035d0dc6fe30120000002003000005000000"
            + "612e7478744b494dcb492c494d4919a547e9511a830600"
            + "504b01021403140000000800cc6d035d0dc6fe30120000002003000005000000"
            + "0000000000000000800100000000612e747874"
            + "504b0506000000000100010033000000350000000000"
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("coriander-zip-deflated-\(UUID().uuidString).zip")
        defer { try? FileManager.default.removeItem(at: url) }
        try XCTUnwrap(Data(hexString: hex)).write(to: url)
        XCTAssertThrowsError(try ZipArchive.readEntries(from: url)) { error in
            guard case ZipArchive.ZipError.malformed(let reason) = error else {
                return XCTFail("expected malformed, got \(error)")
            }
            XCTAssertEqual(reason, "compressed entries unsupported")
        }
    }

    /// Garbage is rejected, and so are traversal entry names — both on read
    /// (defense on the restore path) and on write.
    func testRejectsGarbageAndUnsafeNames() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("coriander-zip-garbage-\(UUID().uuidString).zip")
        defer { try? FileManager.default.removeItem(at: url) }
        try Data("not a zip at all".utf8).write(to: url)
        XCTAssertThrowsError(try ZipArchive.readEntries(from: url))

        for name in ["../escape.txt", "dir/file.txt", ".hidden", "back\\slash"] {
            XCTAssertThrowsError(
                try ZipArchive.write(entries: [ZipArchive.Entry(name: name, data: Data())], to: url),
                "unsafe name accepted: \(name)") { error in
                    guard case ZipArchive.ZipError.unsafeName = error else {
                        return XCTFail("expected unsafeName for \(name), got \(error)")
                    }
                }
        }
    }
}

private extension Data {
    init?(hexString: String) {
        var data = Data()
        var index = hexString.startIndex
        while index < hexString.endIndex {
            let next = hexString.index(index, offsetBy: 2)
            guard let byte = UInt8(hexString[index..<next], radix: 16) else { return nil }
            data.append(byte)
            index = next
        }
        self = data
    }

    var hexString: String { map { String(format: "%02x", $0) }.joined() }
}
