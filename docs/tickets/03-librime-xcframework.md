# 03 — Build librime core and assemble XCFramework

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 02
**Status:** done

## What to build

Compile librime itself against the ticket-02 dependencies and assemble the XCFramework(s) consumable from both app targets, including headers and a Swift bridging path. Collect third-party license files alongside.

## Acceptance criteria

- [x] XCFramework builds for all three slices — `ios-arm64` + `ios-arm64_x86_64-simulator` (sim fat)
- [x] Headers/bridging consumable from Swift — public C API headers + `module.modulemap` (`import Rime`, no C++ exposure)
- [x] Third-party license files collected — `vendor/licenses/` (7 files)
- [x] Build reproducible from clean checkout — `scripts/librime/build-librime.sh` on top of ticket 02's prefixes

## Results

- `scripts/librime/build-librime.sh`: per-slice `rime-static` (BUILD_STATIC=ON, BUILD_TEST=OFF, deps located via `CMAKE_PREFIX_PATH`/`Boost_ROOT` → ticket-02 prefixes), then `libtool -static` merges librime + all 6 dep archives into `librime-combined.a`, lipo for the simulator fat slice, `xcodebuild -create-xcframework` for assembly.
- Output: `.scratch/librime-deps/Rime.xcframework` (gitignored) — verified: correct arch per slice, `Headers/` with `rime_api.h`, `rime_api_stdbool.h`, `rime_levers_api.h`, `rime_api_deprecated.h`, `module.modulemap`.
- Notes: CMake 4.4 removed `FindBoost` (CMP0167) — Boost is located in config mode from the ticket-02 prefix, no module needed. `X11/keysym.h` absence is expected (optional, keysym fallback compiled in). opencc's deprecated `std::iterator` usage is a warning only.
- Link-order note carried from ticket 02: `librime-combined.a` contains exactly one marisa (the marisa-trie build); opencc's marisa symbols resolve against it.
