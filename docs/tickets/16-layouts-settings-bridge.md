# 16 — Layouts + settings bridge

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 08 (done), 22
**Status:** done

## What to build

Extends the native-style portrait layout system (ticket 22) to iPhone landscape, iPad full-size and floating-keyboard presentations; plus the App Group user-defaults bridge that carries UI-layer settings from the Container App to the keyboard.

## Acceptance criteria

- [x] iPhone landscape adapts the ticket 22 layout system without disturbing portrait
- [x] iPad full + floating presentations adapt
- [x] A defaults value set in the app is read by the keyboard
- [x] No layout regressions on compact sizes

## Results

- `KeyboardLayout` gained a `Form` dimension (PR #55): every presentation keeps the ticket 22 structure and only changes the reference each metric scales from. `phoneLandscape` derives vertical metrics from the device's portrait width (native landscape rows run shorter); `padFull` scales from a 768pt reference (rows ~55pt, the iPad counterpart of the 375pt iPhone reference); `padFloating` follows the iPhone-portrait ratios. Form selection is width/idiom-based: iPad picks `padFloating` below 500pt, `padFull` otherwise; iPhone picks landscape on a compact vertical size class.
- The settings bridge is `KeyboardSettings` (`src/Engine`, shared): a tiny wrapper over the App Group `UserDefaults`. The Container App writes, the keyboard re-reads on each presentation so changes apply without a Session restart, and reading needs no Full Access. It is proven end to end by one UI-layer setting — the key-popup toggle in the Container App — per the spec's Settings decision (Rime-layer settings travel the Config Folder + Deploy path instead; the full settings UI is ticket 17). Bridge behavior is pinned by `KeyboardSettingsTests`.
- Review-driven fixes: row-fit algebra re-verified, layout recomputation memoized per width/form change, and the bridge tests added.
- CI note: the first CI run on the PR failed because the `macos-latest` runner image had churned and the pinned simulator name no longer existed — fixed by resolving any available iPhone to a UDID in the workflow (PR #56); the PR's checks then went green on a rebased branch.
- Verification (human device smoke, iPhone, 2026-07-31): landscape adapts with portrait undisturbed; the popup toggle applies on the next keyboard presentation without restarts; compact sizes regression-free. iPad full-size verified by simulator screenshots (docked keyboard renders the adapted geometry, schema menu/punctuation/candidate bar intact) — note that unsigned simulator builds silently lose the App Group entitlement ("App Group container unavailable"), so verification builds must stay signed. The floating presentation could not be triggered on the iOS 26 simulator (pinch-to-float is a no-op under Stage Manager); its geometry is by construction the device-verified iPhone-portrait ratios selected by width, and a visual check is deferred to a real iPad.
