# 19 — Distribution compliance pipeline

**Parent spec:** [docs/spec/mvp.md](../spec/mvp.md)
**Blocked by:** 01
**Status:** ready-for-agent

## What to build

Enroll in the paid Apple Developer Program (account type per ticket 01's decision — start early, org enrollment may take weeks via D-U-N-S). Add the export-compliance declaration (ITSAppUsesNonExemptEncryption=false), PrivacyInfo.xcprivacy with required-reason API entries, a hosted privacy policy page, and distribution signing/provisioning.

## Acceptance criteria

- [ ] Developer Program membership active
- [ ] Export-compliance key in Info.plist
- [ ] Privacy manifest validates (required-reason APIs covered)
- [ ] Privacy policy URL live
- [ ] Distribution signing works (archive succeeds)
