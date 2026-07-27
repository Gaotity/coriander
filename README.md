# Coriander

An early-stage, local-first Rime keyboard for iOS and iPadOS.

> **Status:** Pre-alpha — there is currently no installable build.

## Overview

Coriander aims to bring the flexibility of the Rime input method engine to a
native keyboard experience on iPhone and iPad.

The project is currently focused on planning and foundational development. The
features listed below are goals, not implemented capabilities.

## Design Goals

- **Local-first input:** Keep core input processing on the device. Basic
  keyboard functionality should not depend on network access or Full Access.
- **Rime flexibility:** Support configurable Rime input schemas while defining
  and documenting the compatibility boundary.
- **Native Apple-platform experience:** Adapt to iPhone and iPad layouts,
  orientations, and compact or floating keyboard presentations.
- **Clear privacy behavior:** Explain what data the keyboard can access and why
  before requesting any optional permission.

These goals will be developed within Apple's
[requirements for keyboard extensions](https://developer.apple.com/app-store/review/guidelines/).

## Planned MVP

The first usable version is intended to:

- Integrate [`librime`](https://github.com/rime/librime) with an iOS custom
  keyboard extension.
- Provide basic composition and candidate selection interfaces.
- Import and select compatible Rime schemas. Exact compatibility will be
  defined as the implementation develops.
- Adapt the keyboard interface across iPhone and iPad, including portrait,
  landscape, and floating keyboard presentations where supported.
- Provide a container app for setup, onboarding, and configuration.

## Availability

There are no binaries, TestFlight builds, or App Store releases yet. The
currently intended distribution path is TestFlight testing followed by an App
Store release, without a committed release date.

## Contributing

Issues, design feedback, and use-case discussions are welcome. Please
[open an issue](https://github.com/Gaotity/coriander/issues) to participate.

Code contributions are not open yet. **Please do not submit code pull requests
yet.** A reviewed Contributor License Agreement process will be published
before code contributions open. Contributors will retain ownership of their
work while granting the project the rights needed to maintain and relicense
accepted contributions.

## Licensing

Project-authored code in this repository, unless otherwise noted, is currently
licensed under the [Apache License 2.0](LICENSE).

Future releases of code that the project has the right to relicense may be
offered under source-available terms. No future license, restriction, or change
date has been selected.

Code already published under Apache-2.0, including repository history, will
remain available under those terms. Existing permissions will not be revoked
or retroactively replaced.

Third-party components — including `librime`, Rime schemas, dictionaries, and
bundled or imported assets — remain subject to their respective licenses.

## Acknowledgements

Coriander is built on the work of the
[Rime Input Method Engine](https://rime.im/) community and
[`librime`](https://github.com/rime/librime), which is distributed under the
BSD 3-Clause License.

Coriander is an independent project and is not affiliated with or endorsed by
the Rime project.
