import SwiftUI
import UniformTypeIdentifiers

@main
struct CorianderApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @State private var busy = true
    @State private var status = "Preparing Rime data…"
    @State private var didRun = false
    @State private var confirmsClear = false
    @State private var pickingImport = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                if busy { ProgressView() }
                Text(status)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                Button("Sync + Deploy", action: syncAndDeploy)
                    .disabled(busy)
                // Import (ticket 21): schema files or archives via document
                // picker; the share sheet arrives via onOpenURL below.
                Button("Import Schemas…") {
                    pickingImport = true
                }
                .disabled(busy)
                // User Dictionary management (ticket 15).
                Button("Export User Dictionary") {
                    run("Exporting…", action: UserDictionaryActions.exportNow)
                }
                .disabled(busy)
                Button("Restore User Dictionary") {
                    run("Restoring…", action: UserDictionaryActions.restoreLatest)
                }
                .disabled(busy)
                Button("Clear User Dictionary", role: .destructive) {
                    confirmsClear = true
                }
                .disabled(busy)
                // Settings (ticket 17): Rime-layer schema list + UI-layer
                // preferences; the key-popup toggle from ticket 16 moved here.
                NavigationLink("Settings") { SettingsView() }
                // The Full Access opt-in (ticket 14): local-write-only
                // purpose, per ADR-0003.
                NavigationLink("Full Access") { FullAccessOptInView() }
            }
            .padding()
            .navigationTitle("Coriander")
            .fileImporter(isPresented: $pickingImport,
                          allowedContentTypes: [.yaml, .zip, .data],
                          allowsMultipleSelection: true) { result in
                switch result {
                case .success(let urls):
                    run("Importing…") { ImportActions.importFiles(urls) }
                case .failure(let error):
                    status = "Import failed: \(error.localizedDescription)"
                }
            }
            .onOpenURL { url in
                guard ImportActions.canHandle(url) else { return }
                run("Importing…") { ImportActions.importFiles([url]) }
            }
            .alert("Clear the User Dictionary?", isPresented: $confirmsClear) {
                Button("Clear", role: .destructive) {
                    run("Clearing…", action: UserDictionaryActions.clearNow)
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Everything the User Dictionary has learned is removed. The keyboard keeps working and starts learning over.")
            }
            .onAppear {
                guard !didRun else { return }
                didRun = true
                run { RimeBootstrap.run() }
            }
        }
    }

    private func syncAndDeploy() {
        run("Syncing + Deploying…") { RimeBootstrap.syncAndDeployNow() }
    }

    /// Runs a Rime Directory action off the main thread with a blocking
    /// indicator, then shows its result line.
    private func run(_ stage: String? = nil, action: @escaping () -> String) {
        busy = true
        if let stage { status = stage }
        DispatchQueue.global(qos: .userInitiated).async {
            let result = action()
            DispatchQueue.main.async {
                status = result
                busy = false
            }
        }
    }
}

#Preview { ContentView() }
