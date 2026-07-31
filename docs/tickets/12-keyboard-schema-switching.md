# 12 — In-keyboard schema switching

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 08
**Status:** done

## What to build

A schema menu in the keyboard UI switches schemas inside the Session (select_schema), honoring the deployed enabled-schema list. The Engine gains its schema list/select methods here (first need).

## Acceptance criteria

- [x] Schema menu reachable from the keyboard
- [x] Switching takes effect within the current Session
- [x] Only deployed/enabled schemas are offered

## Results

- The Engine grew its minimal schema surface (first consumer): `Schema { id, name }`, `schemas` (deployed/enabled, in schema_list order, no Session needed), `currentSchemaID`, and `selectSchema(_:)`, which switches within the current Session and rejects ids outside the enabled list.
- Probe findings that shaped the design: `get_schema_list` resolves exactly the deployed default config's `schema_list` (narrowing it via `default.custom.yaml` + Deploy narrows the offered list — so "only enabled offered" is automatic, no filtering code); `select_schema` switches in-Session but librime **drops the in-progress Composition** (the keyboard just refreshes); the selection **persists across Sessions** via `user.yaml` (pinned by `testSchemaSelectionPersistsAcrossSessions`); and librime's `select_schema` accepts **any** id unchecked, so the enabled-list invariant is enforced in `Engine.selectSchema`, not trusted to librime.
- Keyboard: a 方案 key in the function row opens a `UIMenu` listing the deployed Schemas with the Session's current one checkmarked (PR #47).
- Device smoke (2026-07-30, human run) caught a UIKit caching bug: `UIDeferredMenuElement(provider:)` realizes its items only once, so the checkmark froze at first open even though the switch itself worked. Fixed with `UIDeferredMenuElement.uncached` so the menu is recomputed on every presentation (PR #49 — also the first real src-change run of the ticket 11 CI, green on cache hit). Re-smoke confirmed: switching works, candidates follow the new Schema, and the checkmark tracks the current Schema.
