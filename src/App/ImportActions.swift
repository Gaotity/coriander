import Foundation

/// The Container App's Import actions (ticket 21), each returning the
/// status line the UI shows — the RimeBootstrap/UserDictionaryActions
/// pattern. Sources arrive from the document picker or the share sheet; both
/// hand over URLs the app may only read transiently (security-scoped, or
/// another app's Inbox copy), so they are staged into a temp folder first
/// and the Engine seam sees only plain local files.
enum ImportActions {
    static func importFiles(_ urls: [URL]) -> String {
        guard let directory = RimeDirectory.appGroup(), directory.isSeeded else {
            return "Import failed: Rime data not ready"
        }
        do {
            let sources = try stage(urls)
            defer { try? FileManager.default.removeItem(at: sources.folder) }
            let report = try SchemaImport.importFiles(sources.files,
                                                      into: ConfigFolder.documents(),
                                                      directory: directory)
            let names = report.added + report.overwritten
            guard !names.isEmpty else {
                return "Nothing new to import — the Config Folder already matches"
            }
            return "Imported \(names.count) file(s): \(names.joined(separator: ", ")) — Deploy complete; the keyboard picks it up on its next Session"
        } catch {
            return "Import failed: \(error.localizedDescription) — nothing was changed"
        }
    }

    /// Whether a URL delivered to the app (share sheet) is one Import
    /// handles: a local file whose name says yaml or zip.
    static func canHandle(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }
        let name = url.lastPathComponent.lowercased()
        return name.hasSuffix(".yaml") || name.hasSuffix(".yml") || name.hasSuffix(".zip")
    }

    /// Copies every offered URL into one fresh temp folder, preserving file
    /// names. Picker URLs are security-scoped; share-sheet URLs point into
    /// the app's own Inbox — both are copied, never moved.
    private static func stage(_ urls: [URL]) throws
        -> (folder: URL, files: [SchemaImport.Source]) {
        let fm = FileManager.default
        let folder = fm.temporaryDirectory
            .appendingPathComponent("coriander-import-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: folder, withIntermediateDirectories: true)
        var files: [SchemaImport.Source] = []
        for (index, url) in urls.enumerated() {
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let staged = folder
                .appendingPathComponent("\(index)", isDirectory: true)
                .appendingPathComponent(url.lastPathComponent)
            try fm.createDirectory(at: staged.deletingLastPathComponent(),
                                   withIntermediateDirectories: true)
            try fm.copyItem(at: url, to: staged)
            files.append(SchemaImport.Source(name: url.lastPathComponent, url: staged))
        }
        return (folder, files)
    }
}
