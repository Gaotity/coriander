# Coriander

**English** | [简体中文](README.zh-CN.md)

An early-stage, local-first Rime keyboard for iOS and iPadOS.

> **Status:** Pre-alpha — there is currently no installable build.

## Overview

Coriander aims to bring the flexibility of the Rime input method engine to a native keyboard experience on iPhone and iPad.

The project is currently focused on planning and foundational development. The features listed below are goals, not implemented capabilities.

## Design Goals

- **Local-first input:** Keep core input processing on the device. Basic keyboard functionality should not depend on network access or Full Access.
- **Rime flexibility:** Support configurable Rime input schemas while defining and documenting the compatibility boundary.
- **Native Apple-platform experience:** Adapt to iPhone and iPad layouts, orientations, and compact or floating keyboard presentations.
- **Clear privacy behavior:** Explain what data the keyboard can access and why before requesting any optional permission.

These goals will be developed within Apple's [requirements for keyboard extensions](https://developer.apple.com/app-store/review/guidelines/).

## Planned MVP

The first usable version is intended to:

- Integrate [`librime`](https://github.com/rime/librime) with an iOS custom keyboard extension.
- Provide basic composition and candidate selection interfaces.
- Import and select compatible Rime schemas. Exact compatibility will be defined as the implementation develops.
- Adapt the keyboard interface across iPhone and iPad, including portrait, landscape, and floating keyboard presentations where supported.
- Provide a container app for setup, onboarding, and configuration.

## Availability

There are no binaries, TestFlight builds, or App Store releases yet. The currently intended distribution path is TestFlight testing followed by an App Store release, without a committed release date.

## Building from source

Requirements: Xcode (with iOS platform support), [XcodeGen](https://github.com/yonaskolb/XcodeGen), CMake and Ninja (`brew install xcodegen cmake ninja`).

```sh
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer  # if xcode-select points elsewhere
scripts/librime/fetch.sh        # clone pinned librime + submodules into .scratch
scripts/librime/build-deps.sh   # cross-compile third-party deps (3 slices)
scripts/librime/build-librime.sh # assemble Rime.xcframework
xcodegen generate               # regenerate Coriander.xcodeproj from project.yml
```

Then open `Coriander.xcodeproj` or build with `xcodebuild -scheme Coriander`. Build artifacts live under `.scratch/` (gitignored); `Coriander.xcodeproj` is generated from `project.yml` and never committed.

Signing: `DEVELOPMENT_TEAM` is pinned in `project.yml` for the maintainer's device runs — set it to your own Apple team for local device builds.

## Testing

```sh
xcodebuild test -scheme Coriander -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

The suites are hostless unit-test bundles driving the real librime through the Swift Engine seam (`CorianderEngineTests`), plus an isolated lifecycle target (`CorianderLifecycleTests`) probing librime's finalize → re-initialize cycle. Any recent iPhone simulator works.

## Contributing

Issues, design feedback, and use-case discussions are welcome. Please [open an issue](https://github.com/Winn-Gaoti-Studio/coriander/issues) to participate.

Code contributions are not open yet. **Please do not submit code pull requests yet.** A reviewed Contributor License Agreement process will be published before code contributions open. Contributors will retain ownership of their work while granting the project the rights needed to maintain and relicense accepted contributions.

## Licensing

Project-authored code in this repository, unless otherwise noted, is currently licensed under the [Apache License 2.0](LICENSE).

Future releases of code that the project has the right to relicense may be offered under source-available terms. No future license, restriction, or change date has been selected.

Code already published under Apache-2.0, including repository history, will remain available under those terms. Existing permissions will not be revoked or retroactively replaced.

Third-party components — including `librime`, Rime schemas, dictionaries, and bundled or imported assets — remain subject to their respective licenses.

## Acknowledgements

Coriander is built on the work of the [Rime Input Method Engine](https://rime.im/) community and [`librime`](https://github.com/rime/librime), which is distributed under the BSD 3-Clause License.

Coriander is an independent project and is not affiliated with or endorsed by the Rime project.
