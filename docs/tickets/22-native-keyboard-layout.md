# 22 — Native-style keyboard layout (iPhone portrait)

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 08 (done) — can start immediately
**Status:** ready-for-agent

## What to build

Rebuild the iPhone portrait keyboard so the typing chrome matches what iOS-native and Fcitx5-Android users touch on every keypress: iOS-native QWERTY geometry (uniform key widths across rows, row-2 inset, shift/backspace flanking row 3), key-press highlight + popup, shift with lowercase/uppercase/caps-lock states, a 123 numbers/symbols layer, and dedicated punctuation access beside the space bar (e.g. `,` and `。`). The keyboard stays a pure forwarder: shift and layers are UI state that change which character a key sends; key semantics remain in the Rime configuration, not here.

Explicitly out of scope: 九宫格/T9 (a separate ticket if wanted), glide typing, themes/skins (spec Out of Scope), emoji/clipboard toolbars, a number row on the QWERTY layer, and landscape/iPad/floating adaptations (ticket 16).

## Acceptance criteria

- [ ] Letter keys have uniform width across rows; row insets and flanking-key sizes match iOS native geometry
- [ ] Shift cycles lowercase → uppercase → caps lock (double-tap); keycap glyphs follow the state
- [ ] Key press shows native-style highlight + popup
- [ ] 123 layer (digits + common symbols) toggles in and back out
- [ ] Punctuation is reachable from the main layer beside the space bar
- [ ] Candidate bar and the input path do not regress (test suite green + device smoke)
