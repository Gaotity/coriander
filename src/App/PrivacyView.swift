import SwiftUI

/// The privacy explanation (ticket 18), shown in onboarding before the
/// optional Full Access step and re-viewable from Settings. The copy
/// mirrors docs/privacy/privacy-policy.md and only makes claims the code
/// satisfies: neither target contains networking code, and Full Access is
/// used solely for local writes to the User Dictionary (ADR-0003).
struct PrivacyView: View {
    var body: some View {
        ScrollView {
            PrivacyInfoContent()
                .padding()
        }
        .navigationTitle("Privacy")
        .accessibilityIdentifier("privacy-view")
    }
}

/// The privacy copy without navigation chrome, so onboarding can embed it
/// as one of its steps.
struct PrivacyInfoContent: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Coriander never uses the network — no analytics, no crash "
                + "reporting, no update checks, no cloud processing of your "
                + "input. Your keystrokes never leave this device.")
                .fontWeight(.medium)
            Text("Everything Coriander stores stays on your device:")
            VStack(alignment: .leading, spacing: 8) {
                Text("• The User Dictionary — the words the keyboard learns "
                    + "from what you type — in Coriander's shared on-device "
                    + "container. Clear it anytime from the main screen.")
                Text("• Your Rime configuration, in the Config Folder you "
                    + "can see and edit in the Files app.")
                Text("• The bundled schemas and the artifacts compiled "
                    + "from your configuration.")
                Text("• Keyboard layout preferences.")
            }
            .font(.footnote)
            Text("Full Access is optional and is used solely for local "
                + "writes: without it iOS keeps Coriander's shared "
                + "container read-only to the keyboard, so the User "
                + "Dictionary cannot be saved. Typing works either way, "
                + "and Full Access never enables network use — Coriander "
                + "contains no networking code at all.")
            Text("Deleting the app removes all of this data.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview { NavigationStack { PrivacyView() } }
