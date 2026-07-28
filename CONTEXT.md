# Coriander

A local-first Rime keyboard for iOS and iPadOS: a Container App ships a Keyboard Extension that integrates the Rime input method engine. Coriander positions itself as a complement to the Rime ecosystem and adopts its vocabulary.

## Language

### App structure

**Container App**:
The iOS application that ships the Keyboard Extension and provides setup, onboarding, and configuration. It owns all Rime data management — baseline seeding, Import, Export, Deploy, User Dictionary maintenance — and all settings, both Rime-layer (schema list) and UI-layer (Layout preferences). No built-in YAML editor.
_Avoid_: host app, main app

**Keyboard Extension**:
The custom keyboard app extension that presents the input UI and runs input Sessions. The MVP ships exactly one. It performs no Deploy or file management.
_Avoid_: keyboard app, input extension

### Privacy

**Full Access**:
The iOS keyboard permission (`RequestsOpenAccess`) that expands the keyboard sandbox — without it, the Rime Directory is read-only to the keyboard. The Keyboard Extension requests it solely for local write access to the User Dictionary; basic input works without it. Neither process ever uses the network, with or without it.
_Avoid_: open access

### Keyboard UI

**Layout**:
The keyboard's key arrangement and presentation form — QWERTY vs. nine-key, iPhone vs. iPad, portrait vs. landscape, floating and compact adaptations.
_Avoid_: theme, skin, style

### Engine

**Engine**:
The librime instance embedded in a process. Both the Container App and the Keyboard Extension run their own Engine.
_Avoid_: core, backend, Rime instance

**Session**:
A single librime input session. A Keyboard Extension process holds exactly one long-lived Session; switching schemas happens within it. A Deploy invalidates the in-progress Session — the next Session loads the new artifacts.
_Avoid_: conversation, input context

### Input

**Composition**:
The in-progress, not-yet-committed input state — the typed codes and their inline display.
_Avoid_: marked text, preedit, draft

**Candidate**:
One selectable conversion result, with text and comment.
_Avoid_: suggestion, option

**Commit**:
The finalized text inserted into the host app, and the act of inserting it.
_Avoid_: submit, confirm

### Rime data

**Schema**:
A Rime input schema — its YAML definition plus the artifacts compiled from it.
_Avoid_: input method, layout, keymap

**Dictionary**:
A Rime dictionary (`*.dict.yaml` and its compiled form) backing one or more Schemas.
_Avoid_: wordlist, lexicon

**Deploy**:
The librime action that compiles Schemas and Dictionaries into loadable binary artifacts, and the resulting artifact set.
_Avoid_: build, compile, import

**Config Folder**:
The Files-app-visible folder holding the Rime configuration text sources — the single source of truth for configuration. User edits in Files, Import results, and settings writes all land here; they reach the keyboard only after the Container App syncs and Deploys them into the Rime Directory.
_Avoid_: mirror, sync folder

**Export**:
A Container App action: package persistent user state — above all the User Dictionary — into a single archive placed in Files-visible storage for backup or migration. Configuration needs no export; the Config Folder is already visible. Excludes baseline data and compiled artifacts — both are reproducible.
_Avoid_: backup, dump

**Import**:
A Container App-only action: merge external Rime files into the Config Folder, validate them with a Deploy, and roll back entirely on failure. Distinct from Deploy: Import adopts files, Deploy compiles them. Import only overlays; it never deletes existing files.
_Avoid_: install, add schema

**User Dictionary**:
The per-user vocabulary librime accumulates from input (`*.userdb`). The Keyboard Extension is its sole writer during input; only one Engine holds it open at a time. Persisting it requires Full Access; without it, learning is disabled and input continues read-only.
_Avoid_: user lexicon, learned words

**Rime Directory**:
The single directory in the App Group shared container holding all Rime data consumed by the Engines — baseline files seeded by the Container App, configuration synced from the Config Folder, and the User Dictionary. Both processes point their Engine at it; without Full Access the Keyboard Extension's access is read-only.
_Avoid_: data folder, shared container
