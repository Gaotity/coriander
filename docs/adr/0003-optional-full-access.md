# Optional Full Access for User Dictionary persistence

Apple documents that a keyboard extension "cannot share a container with its containing app" by default and that `RequestsOpenAccess` expands the keyboard sandbox; production evidence from Hamster shows the practical shape of that rule: without Full Access the shared container is read-only to the keyboard, so basic typing works but the User Dictionary cannot be persisted. Coriander therefore adopts a tiered model. Without Full Access, the Keyboard Extension reads the Rime Directory read-only — full typing and schema switching, learning disabled. Enabling Full Access is an optional opt-in used solely for local write access to the user's own data; neither process ever uses the network, with or without it. This preserves the README promise that basic keyboard functionality never depends on network access or Full Access, while keeping user learning possible for those who opt in.

## Considered Options

- **Never request Full Access** — rejected: kills User Dictionary persistence and with it Export and management of learned words, which are core to a Rime keyboard.
- **Always require Full Access** — rejected: breaks the promise that basic input works without it, and weakens the privacy story for no functional gain.

## Consequences

- The privacy story becomes: Full Access is requested only to write the user's own data locally; Coriander never uses the network. Onboarding and App Store review notes must state this plainly.
- The keyboard must tolerate a read-only Rime Directory gracefully (learning disabled, no crash) when Full Access is off.
