import SwiftUI

/// The settings screen (ticket 17). Rime-layer settings (the enabled,
/// ordered Schema list) live behind the Schemas link and travel the
/// Config Folder + Deploy path; UI-layer settings (Layout choice, keyboard
/// feel) write the settings bridge, which the keyboard re-reads on each
/// presentation.
struct SettingsView: View {
    @State private var keyboardHeight = KeyboardSettings().keyboardHeight
    @State private var showsKeyPopup = KeyboardSettings().showsKeyPopup

    var body: some View {
        Form {
            NavigationLink("Schemas") { SchemaSettingsView() }
            Section("Keyboard") {
                Picker("Keyboard height", selection: $keyboardHeight) {
                    Text("Standard").tag(KeyboardSettings.KeyboardHeight.standard)
                    Text("Compact").tag(KeyboardSettings.KeyboardHeight.compact)
                }
                .onChange(of: keyboardHeight) { newValue in
                    KeyboardSettings().keyboardHeight = newValue
                }
                Toggle("Key popup", isOn: $showsKeyPopup)
                    .onChange(of: showsKeyPopup) { newValue in
                        KeyboardSettings().showsKeyPopup = newValue
                    }
            }
        }
        .navigationTitle("Settings")
    }
}

#Preview { SettingsView() }
