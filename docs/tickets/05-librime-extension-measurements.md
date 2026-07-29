# 05 — librime inside the extension: real-device measurements

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 04
**Status:** done

## What to build

Temporary harness that initializes librime inside the Keyboard Extension on a real device: measure memory footprint with the baseline dictionary loaded, cold-start time, and probe the jetsam threshold (keyboard memory limits are undocumented; community consensus is ~30-60 MB with silent kills and no crash logs). This validates ADR-0001's premise. Record results here; harness on a throwaway branch.

## Acceptance criteria

- [x] Extension memory footprint with loaded dictionary recorded (device)
- [x] Cold-start time recorded (device)
- [x] Jetsam behavior documented (device)
- [x] Go/no-go note on ADR-0001 details recorded

## Results so far

- Harness is the **real** extension skeleton (not throwaway): `CorianderKeyboard` target (`RequestsOpenAccess: YES`, App Group `group.com.gaotity.coriander`) + Container App "Prepare Rime data" action (seed → initialize → Deploy). The keyboard measures cold start (kernel process-start) and memory at rest / after init / after dictionary load; jetsam probe is a manual button (10 MB chunks until killed).
- Real Rime Directory layout established: `rime/shared` (seeded baseline) + `rime/user` (deployed artifacts) in the App Group container — matching ADR-0001/0002.
- Simulator (M-series, indicative only): seed ~0 s, initialize ~0 s, **Deploy 1.33 s wall time** (measured via `join_maintenance_thread()` — `start_maintenance` returns immediately, deploy is async), **deploy-time memory peak ~497 MB** (≈2× baseline) with `luna_pinyin.table/prism/reverse.bin` produced.
- **ADR-0001 premise validated early:** deploy doubles memory to ~0.5 GB on a desktop-class simulator; inside a ~63 MB-baseline keyboard extension on device this would be jetsam bait. App-side Deploy is the right call.
- librime API notes: 1.17 exposes only `rime_get_api()` (function-pointer struct); deploy completion must be awaited with `join_maintenance_thread()`.
- Vendoring fix folded in: `default.custom.yaml` patches `schema_list` down to the five shipped schemas (prelude's default references bopomofo/cangjie5/quick5/terra_pinyin, which we don't ship — deploy logged "missing input schema" for them).
- Device (iPhone 15 Pro Max / iOS 18.7.3, Full Access on, screen-recorded 2026-07-29): cold start **255 ms** (kernel process-start → `viewDidLoad`); resident memory at rest 64.1 MB → after initialize 64.5 MB → session 67.9 MB → candidates loaded (`nihao`, 5 candidates) 68.6 MB → after teardown 67.7 MB.
- Jetsam probe (device): +10 MB chunks every 0.3 s, last reported `probe 16: 241.5 MB`, killed before probe 17 (~251 MB). iOS silently swapped in the system keyboard — no crash dialog, no user-visible log. Practical ceiling ≈ 240 MB, far above the community-consensus 30-60 MB.
- **Go on ADR-0001 — upgraded from "right call" to "required":** the keyboard input path fits comfortably (~68 MB working set vs. ≈240 MB kill point, cold start 255 ms), but Deploy's ~497 MB peak (simulator) is roughly 2× the kill point, so keyboard-side Deploy would be guaranteed jetsam. App-side Deploy stands.
- Ticket 04's device leg landed here as well: `create_session` / `process_key` / `get_context` all ran clean on device.
