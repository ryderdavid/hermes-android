# Fork handover — Material You and Expressive

Current branch: `feat/expressive` on https://github.com/ryderdavid/hermes-android
(it builds on `feat/backup-full-coverage` and `feat/material-you`).
Upstream: https://github.com/rusty4444/hermes-android (base `63670ab`, v2.1.30+2173).
Design targets: https://claude.ai/artifact/LTFtuBnyjddRXc3XbgmJpB (Material You),
https://claude.ai/artifact/SA3UYuCG2gsuo3PiADX5rT (Hermes Expressive).

## Expressive refactor (2026-10-30): complete

- **All 20 tasks are done.** The OpenSpec change is archived at
  `openspec/changes/archive/2026-10-30-expressive-refactor/`, and its specs
  are merged into `openspec/specs/`. Its 8 epics and task beads are closed.
- **What changed:** an in-repo Material 3 Expressive kit in
  `lib/core/expressive/`:
  - shape marks, spring tokens, the loading indicator and wavy progress
  - segmented lists, and connected and split buttons

  Every main screen is rebuilt on it: Home, Chats, Projects, Activity, More,
  Chat, the approval sheet, Settings, and a new Appearance page. See
  `docs/releases/v2.1.30-you.3.md`.
- **Released:** [v2.1.30-you.3](https://github.com/ryderdavid/hermes-android/releases/tag/v2.1.30-you.3),
  signed with the fork's key. The arm64 APK was also sent to the phone over
  Tailscale.
- **Verified:**
  - `flutter analyze` is clean, the hard-coded colour lint passes, and
    `flutter test` passes 1,717 tests, including 149 goldens and the
    accessibility guidelines.
  - Smoke-tested on the Fire HD 10 against `tools/fake_gateway`: home, chat
    streaming with the Send/Stop morph, Settings, and live theme switching on
    Appearance.
- **Not checked on a device:** the approval sheet. The Fire's saved
  connection uses the REST path, so the fixture never asked for approval.
  Widget tests and goldens cover the sheet.

## Material You redesign (2026-10-23): complete

- **All 35 tasks are done.** The OpenSpec change is archived at
  `openspec/changes/archive/2026-10-23-material-you-redesign/`, and its specs
  now live in `openspec/specs/` (`app-theming`, `chat-composer`,
  `fork-distribution`). All 8 epics and 35 task beads (`hmy-*`) are closed.
- **Released:** [v2.1.30-you.1](https://github.com/ryderdavid/hermes-android/releases/tag/v2.1.30-you.1),
  with split APKs signed with the fork's own key. Notes and the completed
  release checklist are in `docs/releases/v2.1.30-you.1.md`.
- **Verified:** Flutter 3.44.0. `flutter analyze` is clean; `flutter test`
  passes (unit, widget, 125 goldens, accessibility guidelines);
  `tools/check_no_hardcoded_colors.sh` passes. The release APK was
  smoke-tested on a Fire HD 10 (Android 9) against `tools/fake_gateway`.

## What still needs a person

- **Device checks (beads labelled `needs-device-check`).**
  - On an Android 12+ phone: the app follows the wallpaper (`hmy-apu.1`).
  - On an Android 13+ Pixel: themed launcher icon (`hmy-dxa.1`) and the
    splash in dynamic colors (`hmy-dxa.2`).
  - With gesture navigation: edge-to-edge (`hmy-dxa.3`).
  - On Android 14+: predictive back previews (`hmy-dxa.4`).
  Only Android 9 was available here.
- **Real-gateway smoke test.** The on-device run used the synthetic gateway.
  Memory and Skills were not opened on device.
- **Back up the signing key.** `~/.android/hermes-you-release.jks`; the
  password is in the repo-root `key.properties` (gitignored). Every future
  release must use this key, or installs cannot update.

## Follow-ups (open beads, P3)

- `hmy-xfw` Migrate to the standalone `material_ui` package (then
  `dynamic_color` 2.x).
  When it ships the Expressive components, swap them in for
  `lib/core/expressive/`.
- `hmy-4fo` Propose the theming layer upstream as an opt-in.

## Working on the fork

```bash
git clone -b feat/expressive https://github.com/ryderdavid/hermes-android
cd hermes-android
bd bootstrap                     # beads are published to refs/dolt/data
flutter pub get && flutter analyze && flutter test
scripts/sync-upstream.sh         # rebase onto upstream, then analyze + test
```

Read `CLAUDE.md` (build, architecture, conventions) and `docs/FORK.md`
(identity, syncing, releasing, accessibility audit) before changing anything.
