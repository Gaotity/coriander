# 22 — Native-style keyboard layout (iPhone portrait)

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 08 (done) — can start immediately
**Status:** done

## What to build

Rebuild the iPhone portrait keyboard so the typing chrome matches what iOS-native and Fcitx5-Android users touch on every keypress: iOS-native QWERTY geometry (uniform key widths across rows, row-2 inset, shift/backspace flanking row 3), key-press highlight + popup, shift with lowercase/uppercase/caps-lock states, a 123 numbers/symbols layer, and dedicated punctuation access beside the space bar (e.g. `,` and `。`). The keyboard stays a pure forwarder: shift and layers are UI state that change which character a key sends; key semantics remain in the Rime configuration, not here.

Explicitly out of scope: 九宫格/T9 (a separate ticket if wanted), glide typing, themes/skins (spec Out of Scope), emoji/clipboard toolbars, a number row on the QWERTY layer, and landscape/iPad/floating adaptations (ticket 16).

## Acceptance criteria

- [x] Letter keys have uniform width across rows; row insets and flanking-key sizes match iOS native geometry
- [x] Shift cycles lowercase → uppercase → caps lock (double-tap); keycap glyphs follow the state
- [x] Key press shows native-style highlight + popup
- [x] 123 layer (digits + common symbols) toggles in and back out
- [x] Punctuation is reachable from the main layer beside the space bar
- [x] Candidate bar and the input path do not regress (test suite green + device smoke)

## Results

- The layout was rebuilt as three new files plus a controller rewrite (all in `src/Keyboard/`, PR #53): `KeyboardLayout.swift` derives every dimension proportionally from the keyboard view width (ratios taken from the iOS native keyboard at its 375pt reference width), so letter keys are exactly uniform across rows, row 2 staggers by half a key, and shift/backspace are sized so each row fills precisely (each row's total width verified algebraically as `10w + 9g`); `KeyButton.swift` is the key (corner radius, pressed recolor, popup wiring); `KeyPopupView.swift` is the self-contained enlarged-keycap bubble. All constraints re-solve on width change and the total height accounts for `safeAreaInsets.bottom`.
- Probe-driven behavior decisions: letters always forward to the Engine (shift only swaps the forwarded character `a`/`A`; keycap glyphs stay uppercase, native-style, while the shift keycap cycles its three-state glyph; double-tap caps lock uses `tapCount` so multi-touch can't misfire). Probed against the baseline: `,` is consumed and becomes `你,`, digits select Candidates, `.` pages. `。` has no ASCII keysym and the baseline does not consume it (probed), so its fallback commits the first Candidate and inserts `。` literally — matching how bound punctuation behaves. Known edge: without a Composition, `,` inserts an ASCII comma per the ticket's forwarding rule (the Engine could have produced `,`) — flagged in the PR as a possible follow-up ticket.
- Review-driven fixes: the setup hint conflicted with the fixed-height stack (now hides the layers instead), total height missed the safe-area inset, and shift double-tap misjudged under multi-touch (`touches(for:)` instead of `allTouches.first`).
- Preserved through the rewrite: candidate bar, the 方案 menu (including its `UIDeferredMenuElement.uncached` fix), the globe key, backspace/space/return semantics, `clearComposition` on appear, `reloadSessionIfDeployed`, and the pure-forwarder architecture.
- Smoke (device, 2026-07-30, human run): geometry matches the native keyboard; press highlight + popup read correctly (first-row popups shorten their stem, expected); shift cycles and auto-releases after one uppercase letter; double-tap caps lock works; `。` mid-Composition commits the first Candidate plus `。`; digits select Candidates; 123 layer round-trips; the schema menu and candidate bar are regression-free.
