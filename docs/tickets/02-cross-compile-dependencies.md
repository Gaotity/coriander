# 02 — Cross-compile librime's third-party dependencies

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** None — can start immediately (parallel with 01).
**Status:** done

## What to build

Cross-compile the dependencies of a pinned librime version for iOS: boost (regex only), leveldb, marisa, opencc, yaml-cpp, glog — using librime's vendored deps where available, no lua. Three slices: arm64 device, arm64 simulator, x86_64 simulator. Deliver a reproducible build script committed to the repo. Note: upstream librime has removed its legacy iOS make targets, so this is a self-written toolchain driver, not an assembly job.

## Acceptance criteria

- [x] Build script produces all dependency libraries from a clean checkout (`scripts/librime/fetch.sh` + `build-deps.sh`)
- [x] arm64-device + arm64-sim + x86_64-sim slices verified (lipo) — all 18 artifacts pass
- [x] librime version pinned and recorded in the script — **1.17.0** (+ boost 1.89.0, deployment target 16.0)
- [x] No lua / no unnecessary boost libs — regex is librime 1.17's only Boost component

## Results

- Delivered in PR #27 (`scripts/librime/`). Output: `.scratch/librime-deps/<slice>/{include,lib}` (gitignored) + `VERSIONS`.
- librime's deps are git **submodules** (SHAs pinned by the tag), not vendored content; boost downloads separately (sha256-verified).
- opencc needed both its `tools` and `data` subdirectories disabled (in-script idempotent sed): cross-compiling turns the CLI tools into MACOSX_BUNDLE whose install rules fail at generate time, and `data` references the tools. `libopencc` + public headers are installed manually; `CMAKE_SKIP_INSTALL_RULES=ON` is itself fatal when install rules exist (CMake ≥ 4).
- opencc's bundled marisa is compiled but **not** installed — it would clobber the marisa-trie build; libopencc's marisa symbols resolve at final link (ticket 03/04).
- All deps have CMake with minimums compatible with CMake 4.4; marisa-trie needs no autotools.
