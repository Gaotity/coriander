## Problem Statement

Rime users on iPhone and iPad have no good way to bring their own input schemas to a native keyboard. Existing iOS Rime keyboards are either closed or stagnant, and mainstream third-party keyboards ask users to trust cloud processing of their keystrokes. A Rime user wants to type with their own schemas entirely on-device, keep their learned vocabulary local, and manage configuration the way desktop Rime does — files they can see and edit.

## Solution

Coriander ships a Container App plus one Keyboard Extension, each embedding its own Engine (librime instance). All Rime data lives in a shared Rime Directory (App Group container): the Container App seeds baseline data, syncs configuration, Deploys, and validates Imports; the Keyboard Extension only runs input Sessions. Configuration lives in a Files-app-visible Config Folder that users edit directly; a one-way pipeline (Config Folder → sync + Deploy → Rime Directory → keyboard) carries changes to the keyboard. The keyboard never uses the network; Full Access is an optional opt-in used solely to persist the User Dictionary, and basic typing works read-only without it.

## User Stories

1. As a new user, I want a guided onboarding that walks me through enabling the keyboard in iOS Settings, so that I can start typing without guessing the steps.
2. As a new user, I want the Container App to seed baseline Rime data on first launch with visible progress, so that the keyboard works out of the box.
3. As a user, I want to type my schema's codes and see an inline Composition, so that I can see what I am entering before it lands in the text field.
4. As a user, I want a candidate bar showing Candidates with their comments, so that I can pick the intended conversion.
5. As a user, I want to page through Candidates, so that I can reach conversions beyond the first page.
6. As a user, I want schema-defined keybindings (e.g. space commits the first Candidate), so that typing stays fast and matches my desktop habits.
7. As a user, I want to switch Schemas from the keyboard within my Session, so that I do not have to open the Container App.
8. As a user with Full Access on, I want the keyboard to learn my choices into the User Dictionary, so that typing improves over time.
9. As a user with Full Access off, I want typing to work read-only with learning disabled, so that I can use the keyboard with the tightest possible sandbox.
10. As a user, I want the Full Access request to explain that it is used only for local writes, so that I can opt in knowingly.
11. As an iPhone user, I want portrait and landscape Layouts, so that the keyboard is comfortable in any orientation.
12. As an iPad user, I want iPad Layouts including floating-keyboard adaptation, so that the keyboard feels native.
13. As a user, I want to edit Rime configuration files directly in the Files app (Config Folder), so that I can manage configuration like on desktop Rime.
14. As a user, I want my Files edits to reach the keyboard after the Container App next syncs and Deploys, so that changes are applied safely rather than live-patched underneath a running keyboard.
15. As a user, I want to Import schema files or archives from the document picker or share sheet, so that I can bring in community schemas.
16. As a user, I want Imports validated with clear errors and rolled back entirely on failure, so that a bad file can never break my keyboard.
17. As a user, I want Imports to overlay my configuration without deleting anything, so that repeated Imports are safe.
18. As a user, I want to Export my User Dictionary as an archive into Files-visible storage, so that I can back it up or move to a new device.
19. As a user, I want to choose which Schemas are enabled and in what order, so that the keyboard offers only what I actually use.
20. As a user, I want schema-list changes in settings to Deploy automatically, so that I never have to understand Rime internals.
21. As a user, I want the keyboard to pick up a Deploy on its next Session, so that input never changes mid-composition.
22. As a user, I want clear errors when a Deploy fails with last-good artifacts preserved, so that typing never breaks.
23. As a user, I want the keyboard to cold-start quickly without Deploying, so that typing is instant.
24. As a privacy-conscious user, I want neither the keyboard nor the app to use the network, so that my keystrokes never leave the device.
25. As a privacy-conscious user, I want a privacy explanation screen before any optional permission, so that I understand what is accessed and why.
26. As a user, I want UI-layer preferences (Layout choice, keyboard feel), so that I can tune the keyboard to my liking.
27. As a user, I want to clear my User Dictionary from the Container App, so that I can reset learned words.
28. As a reviewer, I want the App Store privacy details to match actual behavior (no network, optional Full Access for local writes), so that the claims are verifiable.

## Implementation Decisions

- Two executables in one Xcode project: the Container App and exactly one Keyboard Extension (`UIInputViewController`). Swift for all project-authored code.
- librime is built as an XCFramework (CMake iOS toolchain, pinned librime version) and linked into both targets. Third-party licenses are bundled per their terms.
- **Engine**: a Swift adapter over the librime C API — the project's single deep module. One Engine per process. Its interface covers session lifecycle, key event handling, schema list/select, Deploy, and sync; librime types never leak past it.
- **Session**: one long-lived Session per Keyboard Extension process; schema switching happens in-session via `select_schema`. A Deploy invalidates the in-progress Session; the next Session loads the new artifacts (no hot swap).
- **Rime Directory**: the single App Group shared container location holding baseline data (seeded by the Container App from the bundle on first launch, with progress UI), configuration synced from the Config Folder, and the User Dictionary. Both processes point their Engine at it.
- **Config Folder**: the Files-app-visible folder (app Documents with file sharing enabled) holding Rime configuration text sources. It is the single source of truth for configuration: user edits in Files, Import results, and settings writes all land here; a one-way pipeline syncs it into the Rime Directory and Deploys. Conflicting edits resolve last-write-wins per file. Changes reach the keyboard only after the Container App next runs a sync + Deploy.
- **Import**: Container App only. Ingests files/archives via document picker or share sheet, merges them into the Config Folder (overlay only, never deletes), validates with a Deploy, and rolls back entirely on failure.
- **Export**: Container App only. Packages persistent state — above all the User Dictionary — into a single archive placed in Files-visible storage. Configuration needs no export (the Config Folder is already visible). Baseline data and compiled artifacts are excluded (reproducible).
- **Deploy**: Container App only, with progress and error reporting; last-good artifacts are preserved on failure.
- **User Dictionary**: the Keyboard Extension is its sole writer during input; only one Engine holds it open at a time across the system. Persisting it requires Full Access; without Full Access the keyboard runs read-only (learning disabled, no crash).
- **Full Access**: the extension declares `RequestsOpenAccess` so users can opt in; onboarding and privacy screens explain that it is used solely for local writes. Neither target contains any networking code.
- **Settings**: Rime-layer settings (schema enable/order) write `default.custom.yaml` in the Config Folder and trigger a Deploy; UI-layer settings (Layout, keyboard feel) are shared with the keyboard via App Group user defaults.
- **Layouts**: iPhone portrait/landscape and iPad (including floating keyboard) adaptations. No theme/skin system in the MVP.
- **Ticket 1 — platform validation** (acceptance criteria measured on a real device, harness kept on a throwaway branch): whether App Groups work on-device under a free Personal Team or require a paid program; App Group read/write behavior with and without Full Access; librime memory footprint and cold-start time inside the extension; baseline seed duration; Deploy duration. Outcomes may adjust ADR-0001/0003 details but not their shape.
- Tickets are split from this spec with blocking edges (GitHub native issue dependencies) via `/to-tickets`.

## Testing Decisions

- **One seam**: the Swift Engine interface, tested with XCTest against real librime running in the app/test process. No librime mocks — the integration itself is where the risk lives.
- A good test asserts external behavior at the Engine interface: key events in, Composition/Candidates/Commit out; schema switching; Deploy validation outcomes; Import overlay and rollback; User Dictionary learning. It never asserts librime internals.
- The Keyboard Extension UI is a thin shell over the Engine and is covered by on-device smoke checks, not unit tests.
- Ticket 1's platform validations are one-off measurements recorded on the issue; the harness lives on a throwaway prototype branch and is not merged to `main`.
- Greenfield repo: the first tests establish the pattern for all later tickets.

## Out of Scope

- Any network use, including an online schema gallery or update checks.
- A built-in YAML editor (Files + external editors cover this).
- Theme/skin system.
- iCloud sync (planned as a later paid feature; per ADR-0002 it will build on the Config Folder).
- More than one Keyboard Extension.
- Exhaustive Rime feature compatibility (e.g. lua plugins, grammar models): the compatibility boundary is defined per-ticket as implementation develops, with Fcitx5 Android parity as the long-term bar.
- Platforms other than iOS/iPadOS.

## Further Notes

- Glossary and architecture: see `CONTEXT.md` and `docs/adr/0001`–`0003` in the repo — they are the source of truth for vocabulary and the decisions this spec rests on.
- Distribution path: TestFlight then App Store (a paid Apple Developer Program membership is required eventually; Ticket 1 determines whether App Groups force it earlier).
- Prior art: Hamster (iOS librime keyboard) validates the overall architecture; Squirrel validates the deploy ritual and data-dir split.


---

_Local copy converted from GitHub issue #5 (now closed). This file is the canonical spec; tickets live in `docs/tickets/`._
