import SwiftUI

@main
struct CorianderApp: App {
    var body: some Scene {
        WindowGroup { ContentView() }
    }
}

struct ContentView: View {
    @State private var status: String?
    @State private var didRun = false

    var body: some View {
        VStack(spacing: 12) {
            if let status {
                Text(status)
                    .font(.footnote)
            } else {
                ProgressView()
                Text("Preparing Rime data…")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .onAppear {
            guard !didRun else { return }  // one Engine per process, ever
            didRun = true
            DispatchQueue.global(qos: .userInitiated).async {
                let result = RimeBootstrap.run()
                DispatchQueue.main.async { status = result }
            }
        }
    }
}

#Preview { ContentView() }
