import Foundation

/// The Container App's User Dictionary management actions (ticket 15), each
/// returning the status line the UI shows — the RimeBootstrap pattern.
/// Export archives land in the app's Documents, Files-visible next to the
/// Config Folder; restore picks the newest archive there (the minimal honest
/// restore path for the app's own archives — the document-picker Import with
/// validation and rollback is ticket 21).
enum UserDictionaryActions {
    static func exportNow() -> String {
        guard let directory = RimeDirectory.appGroup() else {
            return "Export failed: App Group container unavailable"
        }
        do {
            let archive = try UserDictionary.export(directory: directory, into: documents())
            return "Exported \(archive.lastPathComponent) — visible in Files"
        } catch {
            return "Export failed: \(error.localizedDescription)"
        }
    }

    static func restoreLatest() -> String {
        guard let directory = RimeDirectory.appGroup() else {
            return "Restore failed: App Group container unavailable"
        }
        guard let archive = latestArchive() else {
            return "No export archive in Files yet"
        }
        do {
            let restored = try UserDictionary.restore(archive: archive, into: directory)
            bumpUserDictionaryGeneration()
            return "Restored \(restored.joined(separator: ", ")) from \(archive.lastPathComponent) — the keyboard picks it up on its next appearance"
        } catch {
            return "Restore failed: \(error.localizedDescription)"
        }
    }

    static func clearNow() -> String {
        guard let directory = RimeDirectory.appGroup() else {
            return "Clear failed: App Group container unavailable"
        }
        do {
            let cleared = try UserDictionary.clear(directory: directory)
            guard !cleared.isEmpty else { return "Nothing to clear" }
            bumpUserDictionaryGeneration()
            return "Cleared \(cleared.joined(separator: ", ")) — the keyboard starts learning over on its next appearance"
        } catch {
            return "Clear failed: \(error.localizedDescription)"
        }
    }

    /// Signals the keyboard that the User Dictionary's contents changed
    /// underneath it (ENG-69). Bumped only after the change succeeded: a
    /// keyboard appearing between the file work and the write would
    /// otherwise restart its Session onto the not-yet-changed store.
    private static func bumpUserDictionaryGeneration() {
        KeyboardSettings().userDictionaryGeneration += 1
    }

    private static func documents() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static func latestArchive() -> URL? {
        let documents = documents()
        let names = (try? FileManager.default.contentsOfDirectory(atPath: documents.path)) ?? []
        // Timestamped names sort chronologically as plain strings.
        return names
            .filter { $0.hasPrefix(UserDictionary.archivePrefix + "-") && $0.hasSuffix(".zip") }
            .sorted()
            .last
            .map { documents.appendingPathComponent($0) }
    }
}
