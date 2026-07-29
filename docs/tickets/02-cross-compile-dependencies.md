# 02 — Cross-compile librime's third-party dependencies

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** None — can start immediately (parallel with 01).
**Status:** ready-for-agent

## What to build

Cross-compile the dependencies of a pinned librime version for iOS: boost (regex only), leveldb, marisa, opencc, yaml-cpp, glog — using librime's vendored deps where available, no lua. Three slices: arm64 device, arm64 simulator, x86_64 simulator. Deliver a reproducible build script committed to the repo. Note: upstream librime has removed its legacy iOS make targets, so this is a self-written toolchain driver, not an assembly job.

## Acceptance criteria

- [ ] Build script produces all dependency libraries from a clean checkout
- [ ] arm64-device + arm64-sim + x86_64-sim slices verified (lipo)
- [ ] librime version pinned and recorded in the script
- [ ] No lua / no unnecessary boost libs
