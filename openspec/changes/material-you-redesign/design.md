# Design: Material You redesign

## Context

See proposal.md (Why). Current state, from a code audit of upstream v2.1.30 (`63670ab`):

- **One theme builder.** `lib/core/theme/hermes_theme.dart:286` `hermesTheme(Brightness)` already uses `useMaterial3: true` and `ColorScheme.fromSeed(seedColor: hermesGold)`, then overrides `surface`, `onSurface`, `error`, `outlineVariant` with hand-picked hex. Wired in `main.dart:455`.
- **`HermesTokens` ThemeExtension** (same file, :132-283) carries hardcoded dark/light palettes (`surface`, `raised`, `border`, `muted`, `success`, `warning`, `danger`, `running`, `blocked`, `accent`=gold) plus spacing, radius, motion and type scales. Most widgets read color through it — this is the main lever.
- **Leaks.** ~150 hardcoded `Color(0x…)`/`Colors.*` uses across 16 files; worst: `main.dart` (29), `cron_screen.dart` (25), `chat_screen.dart` (19, incl. gold user bubble `:66` and `0xFF2A2A2A` assistant bubble `:5555`), `settings_screen.dart` (10).
- **No button or input themes.** No `filledButtonTheme` / `elevatedButtonTheme` / `inputDecorationTheme`; stadium `ElevatedButton`s are used for Retry in 7 screens while `ErrorState` (`widgets/hermes_components.dart:241`) already exists and is used by 7 others.
- **Composer.** `chat_screen.dart` `_buildInputBar` (4697-5016): dense `TextField` (~40 dp tall, outlined, radius 24) beside three 48 dp circular controls (attach, filled-tonal mic, TTS) and a 48 dp `primaryContainer` send disc. Model selector `TextButton.icon` above. This is the "gold buttons bigger than the text box".
- **Shell.** `widgets/hermes_shell.dart` `NavigationBar` (:247) with `tokens.raised` background and a gold 18%-alpha indicator; `NavigationRail` for tablets.
- **Android side.** Legacy `Theme.Light/Black.NoTitleBar` styles, no monochrome icon layer, default white `launch_background`, no `enableOnBackInvokedCallback`, no edge-to-edge setup. minSdk 24, targetSdk 36.
- **Tests.** 123 test files, no goldens. `test/hermes_theme_test.dart`, `test/widget_test.dart`, `test/hermes_components_test.dart` assert gold/token colors.
- **Flutter platform.** Flutter 3.44 froze in-SDK Material; 3.47 ships `material_ui` 1.0 as an opt-in standalone package where M3 Expressive work is happening.

## Goals / Non-Goals

**Goals:** Pixel-native look via dynamic color; one source of truth for color; M3 component defaults set once in the theme rather than per call site; low-conflict rebase onto upstream.

**Non-Goals:** No navigation/IA changes (tabs, routes, screen set stay as upstream). No networking, auth, or data changes — including the dashboard "Session token not found" error, which is a dashboard-reachability issue, not UI. No Material 3 *Expressive* shapes/motion in this change. No `material_ui` package migration in this change.

## Decisions

### D1. Re-point `HermesTokens` at `ColorScheme` roles instead of deleting it
`HermesTokens` becomes a pure function of the active `ColorScheme`: `surface → surface`, `raised → surfaceContainer`, `border → outlineVariant`, `muted → onSurfaceVariant`, `accent → primary`, `danger → error`; `success`/`warning`/`running`/`blocked` are fixed hues run through `harmonizeWith(primary)`. Spacing/radius/motion stay.
*Why:* hundreds of call sites already read tokens; changing the mapping fixes most of the UI in one file and keeps upstream diffs small. *Alternative:* rip out tokens and use `Theme.of(context).colorScheme` everywhere — cleaner, but a massive diff that conflicts with every upstream release.

### D2. `dynamic_color` ^2.1.0 with `DynamicColorBuilder` around `MaterialApp`
Pass `lightDynamic`/`darkDynamic` (after `.harmonized()`) into `hermesTheme(scheme)`. When null (API < 31) or when the user picks a seed, build with `ColorScheme.fromSeed(seed, brightness, dynamicSchemeVariant: tonalSpot)`. Remove the four hand-picked overrides in `hermesTheme`.
*Alternative:* platform channel to `android.R.color.system_*` — reimplements the package.

### D3. Theme preferences in one store
New `AppearancePreferences` (SharedPreferences) holding `colorSource` (`system | hermesGold | seed:<argb>`), `pureBlack`, and the existing `theme_mode` key (read-compatible). Exposed as a `ValueNotifier`/Riverpod provider so `MaterialApp` rebuilds without the current `findAncestorStateOfType<HermesAppState>().setState` hack in `settings_screen.dart:705-760`. Keys added to the existing backup allow-list.

### D4. Set component defaults in the theme, then delete per-site styling
Add `filledButtonTheme`, `filledButtonTheme.tonal` via `FilledButton.styleFrom`, `outlinedButtonTheme`, `textButtonTheme` (40 dp min height, M3 default padding), `inputDecorationTheme` (filled, `surfaceContainerHighest`, no resting border), `navigationBarTheme` (`surfaceContainer`, default `secondaryContainer` indicator), `appBarTheme` (`centerTitle: false`, `scrolledUnderElevation` tint), `listTileTheme`, `switchTheme` (thumb icon), `snackBarTheme`, `chipTheme`. Then replace the 7 bespoke Retry `ElevatedButton`s with `ErrorState`, and remove `styleFrom` color overrides.
*Why:* call-site edits become deletions (low conflict) rather than rewrites.

### D5. Composer: restructure, don't rewrite
Extract `_buildInputBar` into `lib/core/widgets/chat_composer.dart` with the same callbacks, then restyle: one `InputDecorator` pill (`surfaceContainerHigh`, radius 24, min 48 dp) containing attach (leading) and mic (trailing); a 48 dp `FilledButton`/`IconButton.filled` send/stop outside; model and spoken-reply as an `ActionChip` row above. Keep all state in `ChatScreen`.
*Why:* chat_screen.dart is 5,669 lines and upstream's most-churned file; extraction isolates our diff to one call site plus a new file.

### D6. Settings: Pixel grouped lists
A shared `SettingsGroup` widget (title in `labelLarge`/`primary`, children in a `Card.filled` with `surfaceContainer`, 24 dp corners, 2 dp gaps between rows). Appearance gains *Color* (wallpaper swatch + seed swatches, Pixel-wallpaper-picker style) and *Pure black*. Theme mode stays a `SegmentedButton`.

### D7. Typography
Drop the Cinzel default; use `Typography.material2021` with the platform font (Roboto in Flutter on Android). Optionally bundle Google Sans Flex (OFL, released Nov 2025) behind a hidden setting for a closer Pixel match. Cinzel kept only for the `HermesHeader` wordmark.

### D8. Android shell polish
`styles.xml` → `Theme.Material3.DynamicColors.DayNight.NoActionBar`-equivalent via `androidx.core:core-splashscreen`; monochrome vector for `<monochrome>`; `android:enableOnBackInvokedCallback="true"`; `SystemChrome.setEnabledSystemUIMode(edgeToEdge)` with transparent bars. Fork `applicationId = "com.ryderdavid.hermes_you"` (`.dev` suffix kept for debug), label "Hermes".

### D9. Stay on `package:flutter/material.dart` for now
The `material_ui` migration is mechanical (`dart fix --apply --code=migrate_design_widgets`) and upstream will almost certainly do it; doing it first in the fork would touch every file. Tracked as a follow-up bead.

### D10. Golden tests as the safety net
Add golden tests for Settings, Chat (composer idle/typing/streaming/attachments), Chats list, Home, error state, in {light, dark, dark+pureBlack} × {fixed blue seed, hermesGold}. Dynamic color is simulated with a fixed seed so goldens are deterministic.

## Risks / Trade-offs

- [Upstream churn in chat_screen.dart / main.dart] → isolate via extraction (D5), keep edits to call-site deletions, rebase weekly; a `scripts/sync-upstream.sh` documents the flow.
- [Harmonized status colors lose meaning on odd palettes] → contrast tests on every preset seed; `error` always from scheme.
- [Gold-asserting tests fail] → update those three tests to assert role mapping, not hex.
- [Dynamic color unavailable on some OEM ROMs] → seeded fallback (D2) and the setting shows *System* as unavailable.
- [Flutter renders Roboto, not the Pixel system font] → optional Google Sans Flex (D7).

## Migration Plan

Existing users of the fork get *System* color on first launch; `theme_mode` is preserved. Fork installs alongside upstream (new applicationId), so there is no data migration — the user re-adds connections or uses the existing encrypted config backup/restore. Rollback: install upstream APK.

## Open Questions

- Final preset seed list (proposal: Blue, Green, Purple, Pink, Hermes gold).
- Whether to upstream the theming layer to `rusty4444/hermes-android` as an opt-in setting once stable.
