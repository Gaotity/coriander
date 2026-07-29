# 06 — Baseline data vendoring + license manifest

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 01
**Status:** ready-for-agent

## What to build

Choose the baseline schema set (rime-prelude + one starter schema + essay + opencc data), vendor it into the app bundle with a license manifest covering every bundled asset. Record the prebuilt-artifacts vs deploy-on-first-seed decision here (informed by ticket 05's timing measurements).

## Acceptance criteria

- [ ] Baseline set chosen and vendored into the bundle
- [ ] License manifest lists every bundled Rime asset
- [ ] Bundle size recorded
- [ ] Prebuilt-vs-deploy-on-seed decision recorded with rationale
