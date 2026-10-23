# Fork handover — Material You redesign

Branch `feat/material-you` on https://github.com/ryderdavid/hermes-android.
Upstream: https://github.com/rusty4444/hermes-android (base `63670ab`, v2.1.30+2173).
Design target: https://claude.ai/artifact/LTFtuBnyjddRXc3XbgmJpB

## Status (2026-10-22)

- **Plan:** OpenSpec change `openspec/changes/material-you-redesign/`, 35 tasks in 8 groups. Beads prefix `hmy`, 8 epics, 35 tasks and 3 follow-ups.
- **Done (3/35): tasks 2.1–2.3, the color foundation.**
  - `lib/core/theme/hermes_theme.dart`:
    - `HermesSeeds` holds the seed colors (fallback blue `#4285F4`, Hermes gold `#D4AF37`).
    - `hermesColorScheme(brightness, {dynamicScheme, seed})` picks the scheme.
    - `HermesTokens.fromScheme()` maps the tokens onto scheme roles.
    - `hermesTheme(brightness, {colorScheme})` builds the theme.
  - `lib/main.dart`: `MaterialApp` is wrapped in `DynamicColorBuilder`.
  - `test/hermes_theme_test.dart`: role mapping, fallback, dynamic, seed override, and status-contrast tests.
- **`dynamic_color` is pinned to ^1.9.0, not 2.x.** 2.x depends on the standalone `material_ui` package, whose `ColorScheme` type is incompatible with `package:flutter/material.dart`. See design D2 and D9.
- **Device check pending:** confirm the app follows the wallpaper on Android 12+. Bead `hmy-apu.1` is labelled `needs-device-check`.
- **Verified:** on Flutter **3.44.0**, the version upstream CI uses, `flutter analyze` is clean and all 1,493 tests pass.

## Restore on the Mac

```bash
git clone -b feat/material-you https://github.com/ryderdavid/hermes-android
cd hermes-android
git remote add upstream https://github.com/rusty4444/hermes-android.git
npm i -g @fission-ai/openspec@latest @beads/bd   # if needed
bd bootstrap          # rebuilds the local Dolt DB from .beads/issues.jsonl
bd dolt push          # first publish of beads to refs/dolt/data on the fork
flutter pub get && flutter analyze && flutter test
bd ready
```

## Next up (`bd ready`)

- `hmy-apu.4` [2.4] AppearancePreferences: colorSource, pureBlack, theme_mode compat. Then 2.5, pure black.
- `hmy-fbq.1` [6.1] Extract `_buildInputBar` (`chat_screen.dart:4697-5016`) into `lib/core/widgets/chat_composer.dart` with no visual change.
- `hmy-7nx.*` [1.x] Fork identity:
  - applicationId `com.ryderdavid.hermes_you`
  - update check at `lib/core/services/app_update_service.dart:161`
  - `scripts/sync-upstream.sh`
  - CLAUDE.md Build & Test section

## Conventions for the rest of the work

- **Track progress in both places.** Tick `openspec/changes/material-you-redesign/tasks.md` and close the matching bead. `.beads/openspec-map.json` maps task numbers to bead IDs.
- **Label device-only checks.** If a task's verification needs a phone, close the bead with the label `needs-device-check`.
- **Keep diffs minimal so upstream rebases stay cheap.** Prefer theme-level defaults, and delete per-call-site styling rather than rewriting it.
- **Expect remaining gold until group 4.** Chat bubbles (`chat_screen.dart:66`, `:5555`), settings error panels and several screens still have hardcoded colors. Group 4 removes them.
- **The tests to update when the colors change** are `test/widget_test.dart:11-19` (gold bubble) and `test/hermes_components_test.dart:64,139`.
- **"Session token not found" on the phone's Settings screen is not a UI bug.** It comes from `DashboardClient._fetchToken()` in `connection_manager.dart:1483` — the dashboard on :9119 didn't return its token. Check how the dashboard is started (host, port, auth).

## Suggested first prompt

> Read docs/FORK_HANDOVER.md and openspec/changes/material-you-redesign/. Run `bd ready`, then keep applying the change with the openspec-apply-change skill until all tasks are done: claim each bead, implement, run `flutter analyze` and the relevant tests, tick tasks.md, close the bead, and commit and push per task group.
