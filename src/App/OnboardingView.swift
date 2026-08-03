import SwiftUI
import UIKit

/// The first-launch onboarding (ticket 18): a linear walk through the
/// privacy explanation, enabling the keyboard in iOS Settings, the seed
/// with live progress, and the optional Full Access opt-in — the privacy
/// step always precedes that permission ask. Shown once; CorianderApp
/// gates on OnboardingState and shows it again after a reinstall.
struct OnboardingView: View {
    enum Step: Int, CaseIterable {
        case welcome, privacy, enableKeyboard, seed, fullAccess, done
    }

    /// Called when the flow completes; the caller records OnboardingState.
    let onFinish: () -> Void

    @State private var step = Step.welcome
    @State private var seeded = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    stepContent
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                Divider()
                HStack {
                    if canGoBack {
                        Button("Back") { move(-1) }
                    }
                    Spacer()
                    if step == .done {
                        Button("Start typing", action: onFinish)
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("onboarding-finish")
                    } else {
                        Button("Continue") { move(1) }
                            .buttonStyle(.borderedProminent)
                            .disabled(step == .seed && !seeded)
                            .accessibilityIdentifier("onboarding-continue")
                    }
                }
                .padding()
            }
            .navigationTitle("Welcome to Coriander")
            .navigationBarTitleDisplayMode(.inline)
        }
        .accessibilityIdentifier("onboarding")
    }

    @ViewBuilder private var stepContent: some View {
        switch step {
        case .welcome: welcomeStep
        case .privacy: PrivacyInfoContent()
        case .enableKeyboard: enableKeyboardStep
        case .seed: SeedStep(seeded: $seeded)
        case .fullAccess: fullAccessStep
        case .done: doneStep
        }
    }

    private var canGoBack: Bool {
        // No Back out of the seed step: the first-launch ritual is already
        // running (or done) by the time the user could leave, and every
        // earlier step is reachable again on the next launch.
        step != .welcome && step != .seed
    }

    private func move(_ offset: Int) {
        guard let next = Step(rawValue: step.rawValue + offset) else { return }
        step = next
    }

    private var welcomeStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Coriander is a Rime keyboard that types entirely on your "
                + "device — your schemas, your words, your files.")
            Text("This short setup covers:")
            VStack(alignment: .leading, spacing: 8) {
                Text("• What Coriander can access (spoiler: no network, ever)")
                Text("• Turning the keyboard on in iOS Settings")
                Text("• Preparing your schemas and dictionaries")
                Text("• Optional word learning")
            }
            .font(.footnote)
        }
    }

    private var enableKeyboardStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Coriander is a keyboard, so iOS needs you to turn it on "
                + "once. iOS does not let an app enable its own keyboard — "
                + "these steps are yours to tap:")
            VStack(alignment: .leading, spacing: 8) {
                Text("1. Tap “Open Settings” below — iOS shows Coriander's "
                    + "page in Settings.")
                Text("2. Tap “Keyboards”, then “Add New Keyboard…”.")
                Text("3. Choose “Coriander”.")
                Text("4. Back in any app, tap a text field and switch to "
                    + "Coriander with the globe key.")
            }
            .font(.footnote)
            Button("Open Settings", action: openSettings)
                .accessibilityIdentifier("onboarding-open-settings")
            Text("You can finish this setup first — the remaining steps do "
                + "not need the keyboard enabled.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private var fullAccessStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Optional: let Coriander remember your words.")
            Text("Without Full Access the keyboard types read-only — "
                + "schemas and candidates all work, but the User "
                + "Dictionary cannot be saved between sessions.")
            Text("With Full Access the keyboard can write the User "
                + "Dictionary to Coriander's on-device container. That is "
                + "all it is for — it never enables network use, because "
                + "Coriander contains no networking code at all.")
                .fontWeight(.medium)
            Text("To enable it: Settings → General → Keyboard → Keyboards "
                + "→ Coriander → Allow Full Access. You can also do this "
                + "later from Coriander's main screen.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("Open Settings", action: openSettings)
        }
    }

    private var doneStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("You're set.")
                .font(.headline)
            Text("Enable the keyboard in Settings if you haven't, then "
                + "switch to Coriander with the globe key in any text "
                + "field.")
            Text("Everything you type stays on this device.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

/// The first-launch seed with live progress (ticket 18): the one-time
/// copy of the bundled baseline plus its first Deploy, run through
/// RimeBootstrap's stage callback. Auto-starts on appear; on failure the
/// error line shows with a Retry. Success is read back from the Rime
/// Directory's seeded marker — RimeBootstrap only marks it after the
/// first Deploy completes, so a true marker means the keyboard can start.
private struct SeedStep: View {
    @Binding var seeded: Bool

    @State private var running = false
    @State private var stage: RimeBootstrap.Stage?
    @State private var result: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Coriander is copying its bundled schemas and "
                + "dictionaries into place and compiling them for the "
                + "keyboard. This happens once.")
            if result == nil {
                progressView
            }
            if let result {
                Text(result)
                    .font(.footnote)
                    .foregroundStyle(seeded ? Color.secondary : Color.red)
            }
            if !running && result != nil && !seeded {
                Button("Retry", action: start)
                    .accessibilityIdentifier("onboarding-seed-retry")
            }
        }
        .onAppear {
            if result == nil && !running { start() }
        }
    }

    @ViewBuilder private var progressView: some View {
        switch stage {
        case .copyingBaseline(let copied, let total):
            VStack(alignment: .leading, spacing: 8) {
                ProgressView(value: Double(copied), total: Double(max(total, 1)))
                Text("Copying bundled data… \(copied)/\(total)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        case .preparingConfig:
            stageLine("Preparing the Config Folder…")
        case .syncing:
            stageLine("Syncing configuration…")
        case .deploying:
            stageLine("Compiling dictionaries — this can take a minute…")
        case nil:
            ProgressView()
        }
    }

    private func stageLine(_ label: String) -> some View {
        HStack(spacing: 8) {
            ProgressView()
            Text(label)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func start() {
        running = true
        result = nil
        DispatchQueue.global(qos: .userInitiated).async {
            let outcome = RimeBootstrap.run { newStage in
                DispatchQueue.main.async { stage = newStage }
            }
            let didSeed = RimeDirectory.appGroup()?.isSeeded ?? false
            DispatchQueue.main.async {
                result = outcome
                seeded = didSeed
                running = false
            }
        }
    }
}

#Preview { OnboardingView(onFinish: {}) }
