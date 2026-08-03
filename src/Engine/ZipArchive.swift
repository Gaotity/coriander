import Foundation

/// The single archive behind Export (ticket 15): a plain zip, entries stored
/// uncompressed. Neither Foundation nor the iOS SDK ships a zip facility and
/// the project vendors none, so this is the minimal honest implementation —
/// STORE entries only, central-directory based, no new dependency. Any
/// standard unzip (Files, macOS, `unzip`) reads it.
enum ZipArchive {
    /// One stored file: a plain relative name and its bytes.
    struct Entry {
        let name: String
        let data: Data
    }

    enum ZipError: Error {
        /// An entry name is not a plain relative file name.
        case unsafeName(String)
        /// The archive is not a zip this reader understands (bad structure,
        /// compressed entries, multi-disk).
        case malformed(String)
    }

    /// Fixed DOS timestamp (1980-01-01 00:00) for every entry: archives are
    /// byte-deterministic, and the export date lives in the file name.
    private static let dosTime: UInt16 = 0
    private static let dosDate: UInt16 = (1 << 5) | 1

    /// Writes `entries` as a fresh zip archive at `url`, replacing any
    /// existing file.
    static func write(entries: [Entry], to url: URL) throws {
        for entry in entries {
            guard isSafeName(entry.name) else { throw ZipError.unsafeName(entry.name) }
        }
        var archive = Data()
        var central = Data()
        for entry in entries {
            let name = Data(entry.name.utf8)
            let crc = entry.data.crc32
            let offset = UInt32(archive.count)
            let size = UInt32(entry.data.count)

            archive.appendUInt32(0x0403_4b50) // local file header
            archive.appendUInt16(20) // version needed
            archive.appendUInt16(0) // flags
            archive.appendUInt16(0) // method: store
            archive.appendUInt16(dosTime)
            archive.appendUInt16(dosDate)
            archive.appendUInt32(crc)
            archive.appendUInt32(size) // compressed
            archive.appendUInt32(size) // uncompressed
            archive.appendUInt16(UInt16(name.count))
            archive.appendUInt16(0) // extra length
            archive.append(name)
            archive.append(entry.data)

            central.appendUInt32(0x0201_4b50) // central directory header
            central.appendUInt16(20) // version made by
            central.appendUInt16(20) // version needed
            central.appendUInt16(0) // flags
            central.appendUInt16(0) // method: store
            central.appendUInt16(dosTime)
            central.appendUInt16(dosDate)
            central.appendUInt32(crc)
            central.appendUInt32(size)
            central.appendUInt32(size)
            central.appendUInt16(UInt16(name.count))
            central.appendUInt16(0) // extra length
            central.appendUInt16(0) // comment length
            central.appendUInt16(0) // disk number
            central.appendUInt16(0) // internal attributes
            central.appendUInt32(0) // external attributes
            central.appendUInt32(offset)
            central.append(name)
        }
        let centralOffset = UInt32(archive.count)
        archive.append(central)
        archive.appendUInt32(0x0605_4b50) // end of central directory
        archive.appendUInt16(0) // disk number
        archive.appendUInt16(0) // central directory disk
        archive.appendUInt16(UInt16(entries.count))
        archive.appendUInt16(UInt16(entries.count))
        archive.appendUInt32(UInt32(central.count))
        archive.appendUInt32(centralOffset)
        archive.appendUInt16(0) // comment length
        // Atomic: a truncated zip must never sit in Documents — restore
        // always picks the newest archive there.
        try archive.write(to: url, options: .atomic)
    }

    /// Reads every entry of a zip archive written in the shape above.
    /// Compressed entries are rejected — this reader exists for the app's
    /// own archives, not for arbitrary zips (ticket 21 owns that).
    static func readEntries(from url: URL) throws -> [Entry] {
        let data = try Data(contentsOf: url)
        let eocd = try findEndOfCentralDirectory(in: data)
        guard try data.uint16(at: eocd + 8) == data.uint16(at: eocd + 10) else {
            throw ZipError.malformed("multi-disk archive")
        }
        let count = Int(try data.uint16(at: eocd + 10))
        var offset = Int(try data.uint32(at: eocd + 16))
        var entries: [Entry] = []
        for _ in 0..<count {
            guard try data.uint32(at: offset) == 0x0201_4b50 else {
                throw ZipError.malformed("bad central directory header")
            }
            guard try data.uint16(at: offset + 10) == 0 else {
                throw ZipError.malformed("compressed entries unsupported")
            }
            let crc = try data.uint32(at: offset + 16)
            let size = Int(try data.uint32(at: offset + 20))
            let nameLength = Int(try data.uint16(at: offset + 28))
            let extraLength = Int(try data.uint16(at: offset + 30))
            let commentLength = Int(try data.uint16(at: offset + 32))
            let localOffset = Int(try data.uint32(at: offset + 42))
            let name = try data.string(at: offset + 46, length: nameLength)
            guard isSafeName(name) else { throw ZipError.unsafeName(name) }

            guard try data.uint32(at: localOffset) == 0x0403_4b50 else {
                throw ZipError.malformed("bad local file header")
            }
            let localNameLength = Int(try data.uint16(at: localOffset + 26))
            let localExtraLength = Int(try data.uint16(at: localOffset + 28))
            let dataStart = localOffset + 30 + localNameLength + localExtraLength
            guard dataStart + size <= data.count else {
                throw ZipError.malformed("entry data out of bounds")
            }
            let payload = data[dataStart..<(dataStart + size)]
            guard payload.crc32 == crc else {
                throw ZipError.malformed("crc mismatch in \(name)")
            }
            entries.append(Entry(name: name, data: payload))
            offset += 46 + nameLength + extraLength + commentLength
        }
        return entries
    }

    /// A plain relative file name: no directories, no traversal, no dot
    /// files. Restore sanitizes through this — an archive can only ever
    /// write next to the app's own staging files.
    private static func isSafeName(_ name: String) -> Bool {
        !name.isEmpty && !name.hasPrefix(".")
            && !name.contains("/") && !name.contains("\\") && !name.contains(":")
    }

    /// Locates the end-of-central-directory record by scanning backwards
    /// from the end (a trailing comment would shift it).
    private static func findEndOfCentralDirectory(in data: Data) throws -> Int {
        let minimum = 22
        let scanStart = max(0, data.count - minimum - 0xffff)
        var offset = data.count - minimum
        while offset >= scanStart {
            if offset >= 0, try data.uint32(at: offset) == 0x0605_4b50 {
                return offset
            }
            offset -= 1
        }
        throw ZipError.malformed("no end of central directory")
    }
}

private extension Data {
    var crc32: UInt32 {
        var crc: UInt32 = 0xffff_ffff
        for byte in self {
            crc = (crc >> 8) ^ ZipCRC.table[Int((crc ^ UInt32(byte)) & 0xff)]
        }
        return crc ^ 0xffff_ffff
    }

    mutating func appendUInt16(_ value: UInt16) {
        append(contentsOf: [UInt8(value & 0xff), UInt8(value >> 8)])
    }

    mutating func appendUInt32(_ value: UInt32) {
        append(contentsOf: [UInt8(value & 0xff), UInt8((value >> 8) & 0xff),
                            UInt8((value >> 16) & 0xff), UInt8(value >> 24)])
    }

    func uint16(at offset: Int) throws -> UInt16 {
        guard offset >= 0, offset + 2 <= count else {
            throw ZipArchive.ZipError.malformed("truncated at \(offset)")
        }
        return UInt16(self[offset]) | UInt16(self[offset + 1]) << 8
    }

    func uint32(at offset: Int) throws -> UInt32 {
        guard offset >= 0, offset + 4 <= count else {
            throw ZipArchive.ZipError.malformed("truncated at \(offset)")
        }
        return UInt32(self[offset]) | UInt32(self[offset + 1]) << 8
            | UInt32(self[offset + 2]) << 16 | UInt32(self[offset + 3]) << 24
    }

    func string(at offset: Int, length: Int) throws -> String {
        guard offset >= 0, offset + length <= count,
              let string = String(data: self[offset..<(offset + length)], encoding: .utf8) else {
            throw ZipArchive.ZipError.malformed("bad entry name at \(offset)")
        }
        return string
    }
}

/// CRC-32 (IEEE 802.3, reflected) lookup table, generated at launch.
private enum ZipCRC {
    static let table: [UInt32] = (0..<256).map { index in
        var crc = UInt32(index)
        for _ in 0..<8 {
            crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xedb8_8320 : crc >> 1
        }
        return crc
    }
}
