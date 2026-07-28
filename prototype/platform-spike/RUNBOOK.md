# Platform Spike Runbook (PROTOTYPE — Ticket 01)

On-device measurement steps for the parts an agent cannot automate (device
pairing, enabling the keyboard, toggling Full Access). Everything here assumes
the `prototype/01-platform-spike` branch is checked out.

## Prerequisites

- An iPhone or iPad paired and trusted by this Mac.
- Xcode signed in with your Apple ID (done): Xcode → Settings → Accounts.
- Open `prototype/platform-spike/PlatformSpike.xcodeproj`, select the SpikeApp
  target → Signing & Capabilities → pick your **Personal Team** (Xcode creates
  the signing certificate on first use). Do the same for SpikeKeyboard.
- Watch whether the **App Groups** capability resolves under the Personal Team:
  if the entitlements show an error and the group cannot be provisioned, that
  is itself measurement (a) — record it on issue #6.

## A. Install and enable (first run)

1. Build & run SpikeApp on the device (⌘R).
2. On the device: Settings → General → Keyboard → Keyboards → Add New Keyboard
   → **SpikeKeyboard**. (Leave Allow Full Access **off** for now.)
3. In SpikeApp: Menu → "Run app-side probes", then "Seed benchmark (40 MB)".
   Transcribe the output (or screenshot) onto issue #6.

## B. Read/write matrix — Full Access OFF

4. Open any text field, switch to SpikeKeyboard (globe key).
5. Note the auto-run results on the keyboard label: cold start, resident
   memory, group-read, group-write. Screenshot it.
6. Expected per Hamster's evidence: read OK, write FAIL.

## C. Read/write matrix — Full Access ON

7. Settings → General → Keyboard → Keyboards → SpikeKeyboard → enable
   **Allow Full Access**.
8. Kill and reopen the host app, switch to SpikeKeyboard, re-run probes.
9. Expected: group-write now OK.

## D. What to post on issue #6

- App Groups under Personal Team: works / fails (with the Xcode error text).
- Step 3 outputs (app-side probes, seed benchmark numbers).
- Steps 5 and 8 outputs (the two keyboard matrices, cold start, memory).
- Device model and iOS version.
- **Account-type decision**: individual vs organization (organization needs a
  D-U-N-S number, which can add weeks — see issue #24 for why this matters).

## Notes

- Results are also appended to the shared log (`spike-results.log` in the App
  Group container) whenever writes succeed — "Read shared log" in the app
  shows them.
- Simulator results are plumbing checks only: Full Access sandbox behavior is
  not faithfully enforced there. Only device runs count for the matrix.
