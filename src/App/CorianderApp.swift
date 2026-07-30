import SwiftUI

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

    var body: some View {
        VStack(spacing: 12) {
            if busy { ProgressView() }
            Text(status)
                .font(.footnote)
                .multilineTextAlignment(.center)
            Button("Sync + Deploy", action: syncAndDeploy)
                .disabled(busy)
        }
        .padding()
        .onAppear {
            guard !didRun else { return }
            didRun = true
            run { RimeBootstrap.run() }
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
