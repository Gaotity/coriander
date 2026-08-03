import SwiftUI

/// The Rime-layer settings screen (ticket 17): the enabled, ordered Schema
/// list. Every mutation writes `default.custom.yaml` in the Config Folder
/// via `SchemaSettings` and immediately runs the sync + Deploy ritual that
/// carries the change to the keyboard; the list is re-read from the file
/// after each write, so what shows is what's on disk — no shadow state.
/// Disabling is swipe-to-delete; the last enabled Schema cannot be
/// disabled, so the keyboard always has something to type with. A failed
/// Deploy (e.g. a newly enabled Schema whose source is broken) is reported
/// in the status line, with last-good artifacts preserved (spec story 22).
struct SchemaSettingsView: View {
    /// nil when the App Group container is unavailable (the main screen
    /// already reports that state).
    private let settings = RimeDirectory.appGroup().map {
        SchemaSettings(config: .documents(), directory: $0)
    }

    @State private var entries: [SchemaSettings.Entry] = []
    @State private var status: String?
    @State private var busy = false

    private var enabled: [SchemaSettings.Entry] { entries.filter(\.enabled) }
    private var available: [SchemaSettings.Entry] { entries.filter { !$0.enabled } }

    var body: some View {
        Group {
            if settings == nil {
                Text("Rime data unavailable — finish setup on the main screen first.")
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .padding()
            } else {
                list
            }
        }
        .navigationTitle("Schemas")
        .onAppear { entries = settings?.entries ?? [] }
    }

    private var list: some View {
        List {
            Section {
                ForEach(enabled, id: \.id) { entry in
                    row(entry)
                }
                .onMove(perform: move)
                .onDelete(perform: enabled.count > 1 ? disable : nil)
            } header: {
                Text("Enabled")
            } footer: {
                Text("Edit to reorder or disable. The keyboard offers the enabled Schemas in this order.")
            }
            Section("Available") {
                ForEach(available, id: \.id) { entry in
                    Button { enable(entry) } label: {
                        HStack {
                            row(entry)
                            Spacer()
                            Image(systemName: "plus.circle")
                        }
                    }
                    .foregroundStyle(.primary)
                }
            }
        }
        .toolbar { EditButton() }
        .disabled(busy)
        .safeAreaInset(edge: .bottom) {
            if busy || status != nil {
                HStack(spacing: 8) {
                    if busy { ProgressView() }
                    if let status {
                        Text(status)
                            .font(.footnote)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer()
                }
                .padding()
                .background(.bar)
            }
        }
    }

    private func row(_ entry: SchemaSettings.Entry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.name)
            Text(entry.id)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var enabled = enabled
        enabled.move(fromOffsets: source, toOffset: destination)
        entries = enabled + available
        save()
    }

    private func disable(at offsets: IndexSet) {
        var enabled = enabled
        for index in offsets { enabled[index].enabled = false }
        entries = enabled + available
        save()
    }

    private func enable(_ entry: SchemaSettings.Entry) {
        var entry = entry
        entry.enabled = true
        // A newly enabled Schema joins at the end; reorder from there.
        entries = enabled + [entry] + available.filter { $0.id != entry.id }
        save()
    }

    /// Writes the enabled list to the Config Folder, then syncs + Deploys
    /// off the main thread (the ContentView pattern); the entries are then
    /// re-read from disk.
    private func save() {
        guard let settings else { return }
        let ids = enabled.map(\.id)
        busy = true
        status = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let result: String
            do {
                try settings.save(enabledIDs: ids)
                result = RimeBootstrap.syncAndDeployNow()
            } catch {
                result = "Save failed: \(error.localizedDescription)"
            }
            let reloaded = settings.entries
            DispatchQueue.main.async {
                status = result
                entries = reloaded
                busy = false
            }
        }
    }
}

#Preview { SchemaSettingsView() }
