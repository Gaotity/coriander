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
    @State private var showsKeyPopup = KeyboardSettings().showsKeyPopup
    // PROBE16: auto-focused field so the keyboard appears without taps.
    @FocusState private var probeFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            if busy { ProgressView() }
            Text(status)
                .font(.footnote)
                .multilineTextAlignment(.center)
            Button("Sync + Deploy", action: syncAndDeploy)
                .disabled(busy)
            // The settings bridge's one end-to-end setting (ticket 16);
            // the full settings UI is ticket 17.
            Toggle("Key popup", isOn: $showsKeyPopup)
                .onChange(of: showsKeyPopup) { newValue in
                    KeyboardSettings().showsKeyPopup = newValue
                }
            // PROBE16: focus is delayed until seeding should have finished.
            TextField("probe", text: .constant(""))
                .focused($probeFocused)
        }
        .padding()
        .onAppear {
            guard !didRun else { return }
            didRun = true
            run { RimeBootstrap.run() }
            // PROBE16: flip the bridge value through the same write path
            // the toggle uses, so the keyboard's next presentation proves
            // the read; removed before merge.
            DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                KeyboardSettings().showsKeyPopup = false
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 15) { probeFocused = true }
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
