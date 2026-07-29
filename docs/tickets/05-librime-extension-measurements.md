# 05 — librime inside the extension: real-device measurements

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 04
**Status:** in-progress (harness built and simulator-verified; device numbers pending human run)

## What to build

Temporary harness that initializes librime inside the Keyboard Extension on a real device: measure memory footprint with the baseline dictionary loaded, cold-start time, and probe the jetsam threshold (keyboard memory limits are undocumented; community consensus is ~30-60 MB with silent kills and no crash logs). This validates ADR-0001's premise. Record results here; harness on a throwaway branch.

## Acceptance criteria

- [ ] Extension memory footprint with loaded dictionary recorded (device)
- [ ] Cold-start time recorded (device)
- [ ] Jetsam behavior documented (device)
- [ ] Go/no-go note on ADR-0001 details recorded

## Results so far

- Harness is the **real** extension skeleton (not throwaway): `CorianderKeyboard` target (`RequestsOpenAccess: YES`, App Group `group.com.gaotity.coriander`) + Container App "Prepare Rime data" action (seed → initialize → Deploy). The keyboard measures cold start (kernel process-start) and memory at rest / after init / after dictionary load; jetsam probe is a manual button (10 MB chunks until killed).
- Real Rime Directory layout established: `rime/shared` (seeded baseline) + `rime/user` (deployed artifacts) in the App Group container — matching ADR-0001/0002.
- Simulator (M-series, indicative only): seed ~0 s, initialize ~0 s, **Deploy 1.33 s wall time** (measured via `join_maintenance_thread()` — `start_maintenance` returns immediately, deploy is async), **deploy-time memory peak ~497 MB** (≈2× baseline) with `luna_pinyin.table/prism/reverse.bin` produced.
- **ADR-0001 premise validated early:** deploy doubles memory to ~0.5 GB on a desktop-class simulator; inside a ~63 MB-baseline keyboard extension on device this would be jetsam bait. App-side Deploy is the right call.
- librime API notes: 1.17 exposes only `rime_get_api()` (function-pointer struct); deploy completion must be awaited with `join_maintenance_thread()`.
- Vendoring fix folded in: `default.custom.yaml` patches `schema_list` down to the five shipped schemas (prelude's default references bopomofo/cangjie5/quick5/terra_pinyin, which we don't ship — deploy logged "missing input schema" for them).
- Remaining (human device run): enable the keyboard, read cold start + staged memory, tap the jetsam probe and note where it dies; record device model/iOS version. iPhone 15 Pro Max / iOS 18.7.3 available.
