# Coriander Privacy Policy

Effective date: 2026-08-03

Coriander is a local-first Rime keyboard for iOS and iPadOS, consisting of a Container App and a Keyboard Extension. This policy describes what data Coriander can access, where that data lives, and the choices you have. The short version: Coriander never uses the network, and your keystrokes never leave your device.

## No network access, ever

Neither the Container App nor the Keyboard Extension uses the network — no analytics, no crash reporting, no update checks, no cloud processing of your input. This holds with or without Full Access enabled. Everything Coriander does happens on your device.

## What is stored, and where

Coriander stores the following data locally on your device:

- **User Dictionary** — the vocabulary the keyboard learns from what you type and select, held in the Rime Directory inside the App Group container shared between the Container App and the Keyboard Extension. Learning can be reset at any time with the Clear action in the Container App.
- **Configuration** — your Rime schemas and settings files in the Config Folder, a folder in the Container App's Documents that is visible and editable in the iOS Files app.
- **Baseline data and deployed artifacts** — the bundled Rime schemas and dictionaries, and the compiled artifacts produced from your configuration, all held in the Rime Directory.
- **Interface preferences** — keyboard layout and feel settings, stored in the App Group's user defaults so the keyboard can read them.

None of this data is transmitted anywhere by Coriander.

## Full Access

The Keyboard Extension declares Full Access (`RequestsOpenAccess`) for exactly one purpose: without it, iOS makes the shared container read-only to the keyboard, so the User Dictionary cannot be persisted and learning is disabled. With Full Access on, the keyboard gains local write access to the Rime Directory — nothing more. Full Access never enables network use in Coriander, because Coriander contains no networking code at all. Basic typing works with Full Access off.

## What you can do with your data

- **Export** — the Container App can package your User Dictionary into a zip archive placed in Files-visible storage. Export happens only when you tap it; the resulting file is yours to keep, move, or delete through the Files app.
- **Import** — you can bring in schema files or archives through the document picker or share sheet. Imported files stay on your device.
- **Clear** — you can reset the User Dictionary from the Container App.
- **Delete** — deleting the app removes its containers, including the Rime Directory, the Config Folder, and all learned vocabulary.

Files you move out of Coriander through the iOS Files app or document picker are handled by iOS itself, under your control; Coriander plays no part in where they go next.

## Third parties

Coriander collects no data and shares nothing with third parties, because no data ever leaves the device. Coriander embeds the open-source librime input method engine, which runs entirely on-device. There are no advertising, analytics, or tracking SDKs. Coriander does not use Apple's App Tracking Transparency framework because it does not track you.

## Children's privacy

Coriander collects no personal information from anyone, including children.

## Changes to this policy

If this policy changes, the updated version will be published at the same URL with a new effective date. Since Coriander has no network access, it cannot notify you in-app; the policy is versioned in the project's source repository.

## Contact

Questions about this policy can be raised as an issue on the project repository: https://github.com/Winn-Gaoti-Studio/coriander/issues
