# 04 — Link smoke test

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 03
**Status:** in-progress (simulator done; device pending human run)

## What to build

Thinnest possible smoke: an app target links the XCFramework, prints the librime version on screen, and creates/destroys a Rime session without crashing, on both simulator and device.

## Acceptance criteria

- [x] App shows librime version on simulator — `1.17.0` (device pending human run: build & run `Coriander` scheme, read the on-screen log)
- [x] Session create/destroy runs clean — create → destroy → finalize all OK (simulator console)
- [x] No linker/arch warnings unresolved

## Results

- Real project skeleton born: root `project.yml` (XcodeGen) + `src/App/` — this is the Container App's starting point, not a throwaway.
- librime 1.17 exposes the API as `rime_get_api()` returning a struct of function pointers; the classic free functions are deprecated. Swift drives it via the `Rime` module (module map in the XCFramework Headers) with zero C++ exposure.
- Link recipe for a static-library XCFramework consumed by a Swift target (see `project.yml`): `SWIFT_INCLUDE_PATHS` and `LIBRARY_SEARCH_PATHS` per SDK pointing at the slice dirs, `OTHER_LDFLAGS = -lrime-combined -lc++`. The `-l` flag maps `X` → `libX.a`, so the flag is `-lrime-combined`, not `-llibrime-combined`. Pure Swift targets must add `-lc++` for librime's C++ symbols.
- **Erratum for ticket 03:** the first XCFramework silently omitted librime itself — `build-librime.sh` referenced `librime-static.a` but the target's OUTPUT_NAME is `rime` (`lib/librime.a`), and macOS `libtool -static` merely warns on missing inputs (exit 0). The script now merges `lib/librime.a` and hard-verifies `_rime_get_api` in the combined archive (beware `grep -q` + `pipefail` + SIGPIPE false negatives — use full-read grep instead).
- Simulator evidence (console): `get_version: 1.17.0` / `setup + initialize: done` / `create_session: ok` / `destroy_session: ok` / `finalize: done`. Final `xcodebuild` log shows `BUILD SUCCEEDED` with no linker warnings.
- Remaining (human): build & run on a paired device, confirm the same on-screen log; fold into the ticket-01 device session.
