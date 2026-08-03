import SwiftUI
import UIKit

/// The Full Access opt-in screen (ticket 14, ADR-0003): the keyboard types
/// without Full Access; opting in lets it persist the User Dictionary, and
/// the permission is used solely for those local writes — neither process
/// ever uses the network. The full onboarding/privacy flow is ticket 18.
struct FullAccessOptInView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Coriander types without Full Access: your schemas and "
                    + "candidates work read-only.")
                Text("Allow Full Access only if you want the keyboard to "
                    + "remember your words. It grants write access to "
                    + "Coriander's shared Rime data on this device, so your "
                    + "User Dictionary is saved and your words rank up over "
                    + "time.")
                Text("Full Access is used solely for these local writes. "
                    + "Coriander never uses the network — with or without it.")
                    .fontWeight(.medium)
                Text("To enable it: Settings → General → Keyboard → "
                    + "Keyboards → Coriander → Allow Full Access.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("Open Settings") {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                    UIApplication.shared.open(url)
                }
            }
            .padding()
        }
        .navigationTitle("Full Access")
        .accessibilityIdentifier("full-access-opt-in")
    }
}

#Preview { NavigationStack { FullAccessOptInView() } }
