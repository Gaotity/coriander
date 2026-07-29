# 04 — Link smoke test

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 03
**Status:** done

## What to build

Thinnest possible smoke: an app target links the XCFramework, prints the librime version on screen, and creates/destroys a Rime session without crashing, on both simulator and device.

## Acceptance criteria

- [x] App shows librime version — `1.17.0` (simulator on-screen; device leg superseded, see Results)
- [x] Session create/destroy runs clean — create → destroy → finalize all OK (simulator console; device via ticket 05 harness)
- [x] No linker/arch warnings unresolved

## Results

- Real project skeleton born: root `project.yml` (XcodeGen) + `src/App/` — this is the Container App's starting point, not a throwaway.
- librime 1.17 exposes the API as `rime_get_api()` returning a struct of function pointers; the classic free functions are deprecated. Swift drives it via the `Rime` module (module map in the XCFramework Headers) with zero C++ exposure.
- Link recipe for a static-library XCFramework consumed by a Swift target (see `project.yml`): `SWIFT_INCLUDE_PATHS` and `LIBRARY_SEARCH_PATHS` per SDK pointing at the slice dirs, `OTHER_LDFLAGS = -lrime-combined -lc++`. The `-l` flag maps `X` → `libX.a`, so the flag is `-lrime-combined`, not `-llibrime-combined`. Pure Swift targets must add `-lc++` for librime's C++ symbols.
- **Erratum for ticket 03:** the first XCFramework silently omitted librime itself — `build-librime.sh` referenced `librime-static.a` but the target's OUTPUT_NAME is `rime` (`lib/librime.a`), and macOS `libtool -static` merely warns on missing inputs (exit 0). The script now merges `lib/librime.a` and hard-verifies `_rime_get_api` in the combined archive (beware `grep -q` + `pipefail` + SIGPIPE false negatives — use full-read grep instead).
- Simulator evidence (console): `get_version: 1.17.0` / `setup + initialize: done` / `create_session: ok` / `destroy_session: ok` / `finalize: done`. Final `xcodebuild` log shows `BUILD SUCCEEDED` with no linker warnings.
- Device leg (iPhone 15 Pro Max / iOS 18.7.3): landed stronger than the original on-screen-log plan, via later tickets — ticket 06/07's app bootstrap ran the full `setup → initialize → Deploy → shutdown` Engine lifecycle on device (`Rime data ready`), and ticket 05's keyboard harness ran `create_session` / `process_key` / `get_context` inside the extension on device (5 candidates for `nihao`). `RimeSmoke` itself was retired in ticket 07 once the XCTest seam superseded it.
