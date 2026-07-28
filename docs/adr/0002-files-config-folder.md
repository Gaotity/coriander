# Files-visible Config Folder as configuration source of truth

Rime users expect direct file access to their configuration (the `~/Library/Rime` culture), and Coriander commits to exposing it in the iOS Files app. iOS only exposes an app's own Documents directory to Files, while the Keyboard Extension can only read the App Group shared container — the two can never be the same directory, so a copy layer is unavoidable. Instead of a two-way live mirror, configuration flows one way: the Files-visible Config Folder is the single source of truth for Rime configuration text; the Container App syncs it into the Rime Directory and Deploys, and the keyboard only ever reads deployed artifacts. Persistent state (the User Dictionary, compiled artifacts) is never mirrored; it moves via Export archives through Files-visible storage. This preserves the hybrid the project wants: configuration feels live and directly editable, while binary state stays safe behind transfer semantics.

## Considered Options

- **Pure transfer folder** (Files is only an inbox/outbox for Import/Export) — rejected: power users lose the direct config editing that defines desktop Rime usage.
- **Two-way live mirror of the whole Rime Directory** — rejected: iOS offers no reliable background file watching, and the continuously-written, binary User Dictionary cannot be mirrored safely; conflict resolution would be a permanent source of corruption.

## Consequences

- Files edits are visible immediately but reach the keyboard only after the Container App next runs a sync + Deploy — the same manual ritual as Squirrel's redeploy.
- Conflicting edits to the same file (Files vs. settings UI) resolve as last-write-wins per file.
- Import merges into the Config Folder; exporting configuration is unnecessary because it is already visible.
- A future iCloud sync feature should build on the Config Folder rather than the Rime Directory.
