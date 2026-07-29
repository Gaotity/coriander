# 14 — User Dictionary learning + Full Access tiering

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 08
**Status:** ready-for-agent

## What to build

Persist the User Dictionary from the keyboard when Full Access is granted; without it, run read-only — learning disabled, no crash. Add the opt-in screen explaining Full Access is used solely for local writes (per ADR-0003). Only one Engine holds the User Dictionary open at a time.

## Acceptance criteria

- [ ] With Full Access: coined words persist and rank up across Sessions
- [ ] Without Full Access: typing works read-only, nothing persists, no crash
- [ ] Opt-in screen states local-write-only purpose
- [ ] Single-writer rule respected
