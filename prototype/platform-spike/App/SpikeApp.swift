// PROTOTYPE — Ticket 01 platform validation spike. Throwaway; never merge to main.
import SwiftUI

@main
struct SpikeApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @State private var log = "Platform spike — run probes, then read the runbook.\n"

    private func report(_ text: String) {
        log += text + "\n"
        NSLog("%@", text)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(log)
                    .font(.system(.footnote, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("Spike")
            .onAppear { runAppProbes() }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Menu("Probes") {
                        Button("Run app-side probes") { runAppProbes() }
                        Button("Seed benchmark (40 MB)") { runSeedBenchmark() }
                        Button("Read shared log") { report("--- shared log ---\n" + ProbeKit.readGroupLog()) }
                        Button("Clear") { log = "" }
                    }
                }
            }
        }
    }

    private func runAppProbes() {
        report("== app-side probes ==")
        report(String(format: "resident memory: %.1f MB", ProbeKit.residentMemoryMB()))
        let write = ProbeKit.probeGroupWrite()
        report(write.description)
        report(ProbeKit.probeGroupRead().description)
        report(ProbeKit.logToGroup("app-side probe complete, write=\(write.ok)").description)
    }

    private func runSeedBenchmark() {
        report("== seed benchmark ==")
        report(String(format: "resident memory before: %.1f MB", ProbeKit.residentMemoryMB()))
        let result = ProbeKit.seedBenchmark()
        report(result.description)
        report(String(format: "resident memory after: %.1f MB", ProbeKit.residentMemoryMB()))
        report(ProbeKit.logToGroup(result.description).description)
    }
}

#Preview { ContentView() }
