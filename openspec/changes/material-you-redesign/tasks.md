# Tasks

## 1. Fork identity and tooling

- [ ] 1.1 Change `applicationId` to `com.ryderdavid.hermes_you` (keep `.dev` debug suffix) and launcher label to "Hermes"; verify `flutter build apk --debug` installs beside upstream on a device.
- [ ] 1.2 Point `app_update_service.dart` release URL at the fork's GitHub releases and add fork + upstream links to the About card; verify with a widget test that mocks the releases API.
- [ ] 1.3 Add `scripts/sync-upstream.sh` (fetch `upstream`, rebase `main`, run `flutter analyze && flutter test`) and document it in `docs/FORK.md`; verify by running it once against upstream `main`.
- [ ] 1.4 Fill in the Build & Test and Architecture sections of `CLAUDE.md`/`AGENTS.md` with the Flutter commands; verify an agent can run `flutter analyze && flutter test` from those instructions.

## 2. Color foundation

- [x] 2.1 Add `dynamic_color: ^1.9.0` (2.x needs `material_ui`, see D2); wrap `MaterialApp` in `DynamicColorBuilder` and change `hermesTheme` to take a `ColorScheme`; verify on an Android 12+ device that primary follows the wallpaper.
- [x] 2.2 Remove the hand-picked `surface`/`onSurface`/`error`/`outlineVariant` overrides; implement seeded fallback with `DynamicSchemeVariant.tonalSpot`; unit-test fallback when dynamic schemes are null.
- [x] 2.3 Re-map `HermesTokens` colors to `ColorScheme` roles and harmonized status hues (design D1); update `test/hermes_theme_test.dart` to assert role mapping and WCAG contrast for every preset seed.
- [x] 2.4 Add `AppearancePreferences` (colorSource, pureBlack, theme_mode compat) as a provider; replace the `findAncestorStateOfType` rebuild in `settings_screen.dart`; add keys to config backup; unit-test persistence and backup round-trip.
- [x] 2.5 Implement *Pure black* dark variant (background/surface `#000000`, containers tonal); golden-test dark vs dark+pureBlack.

## 3. Component themes

- [ ] 3.1 Add filled/tonal/outlined/text button themes (40 dp height, M3 padding/shape) to `hermesTheme`; golden-test a button gallery in light/dark.
- [ ] 3.2 Add `inputDecorationTheme` (filled, `surfaceContainerHighest`, no resting border, focused primary indicator); verify connection dialog and cron editor fields in goldens.
- [ ] 3.3 Theme `NavigationBar`/`NavigationRail` (`surfaceContainer`, default `secondaryContainer` indicator) and remove gold indicator overrides in `hermes_shell.dart`; golden-test phone and tablet shells.
- [ ] 3.4 Theme AppBar (left-aligned title, `scrolledUnderElevation` tint), ListTile, Switch (thumb icons), Chip, SnackBar, Dialog, BottomSheet (drag handle), FAB (`primaryContainer`); remove `Colors.black` FAB icon in `main.dart:1322`; verify via goldens.
- [ ] 3.5 Switch typography to `Typography.material2021` + platform font; restrict Cinzel to `HermesHeader`; verify text scale 1.3 goldens show no clipping.

## 4. Remove hardcoded colors

- [ ] 4.1 `main.dart` (29 uses incl. `HermesHeader` black/gold at :508/:521, :1175): replace with scheme roles; verify `grep -nE "Color\(0x|Colors\." lib/main.dart` returns only allowed exceptions.
- [ ] 4.2 `chat_screen.dart` (19 uses): user bubble → `primaryContainer`/`onPrimaryContainer`, assistant bubble → `surfaceContainerHigh`/`onSurface`, orange snackbars → themed SnackBar; update `test/widget_test.dart` bubble assertions.
- [ ] 4.3 `cron_screen.dart`, `settings_screen.dart`, `session_list_screen.dart`, `memory_screen.dart`, `skills_screen.dart`: replace `Colors.red/orange/green/grey` with error/tertiary/harmonized-success/onSurfaceVariant; verify grep is clean.
- [ ] 4.4 Remaining widgets (`markdown_code_block`, `media_artifact_card`, `config_backup_card`, `hermes_components`, gateway cards, `attachment_draft_tile`, `workspace_sessions_screen`); code blocks use `surfaceContainerHighest` with a syntax palette derived from scheme; update `test/hermes_components_test.dart`.
- [ ] 4.5 Add a CI lint script `tools/check_no_hardcoded_colors.sh` (allow-list: theme module) and run it in `flutter test` workflow; verify it fails on a planted `Colors.red`.

## 5. Shared states and Settings

- [ ] 5.1 Restyle `ErrorState`/`EmptyState` (icon in `error`/`onSurfaceVariant`, `headlineSmall` title, `FilledButton.tonal` Retry at 40 dp); golden-test both.
- [ ] 5.2 Replace bespoke error UIs with `ErrorState` in settings (:187-222), chat (:5023-5050), session list (~:1250), memory, cron, skills; verify each screen's failure path in widget tests.
- [ ] 5.3 Build `SettingsGroup` and convert Settings to Pixel-style grouped lists; golden-test the full Settings screen in light/dark.
- [ ] 5.4 Add Appearance → *Color* picker (wallpaper swatch + presets + Hermes gold) and *Pure black* switch; *System* disabled below API 31; widget-test selection applies immediately and persists.

## 6. Chat composer

- [ ] 6.1 Extract `_buildInputBar` into `lib/core/widgets/chat_composer.dart` with no visual change; verify all existing chat/composer tests pass unchanged.
- [ ] 6.2 Restyle to a single 48 dp `surfaceContainerHigh` pill with inline attach (leading) and mic (trailing); restyle `VoiceComposerStartButton` as a standard icon button; golden-test idle and multiline.
- [ ] 6.3 Send/Stop as one ≤48 dp filled icon button outside the pill, bottom-aligned, disabled-styled when empty; widget-test empty → typing → streaming → stopped states.
- [ ] 6.4 Move model selector and spoken-reply toggle into a compact `ActionChip`/`FilterChip` row above the pill; widget-test that the model picker still opens and TTS toggle persists.
- [ ] 6.5 Verify parity: attachments tray (reorder/remove/retry), Enter-to-send, per-chat drafts, keyboard insets on narrow/landscape/large-text (reuse PR #139 regressions).

## 7. Android platform polish

- [ ] 7.1 Add monochrome vector to `mipmap-anydpi-v26/ic_launcher.xml` and fix `ic_launcher_round`; verify themed icon on a Pixel with themed icons enabled.
- [ ] 7.2 Adopt `androidx.core:core-splashscreen` with DayNight launch theme and monochrome glyph; verify no white flash on dark cold start.
- [ ] 7.3 Enable edge-to-edge with transparent system bars and correct icon brightness per theme; verify on gesture and 3-button navigation.
- [ ] 7.4 Add `android:enableOnBackInvokedCallback="true"` and audit `WillPopScope`/`PopScope` usage; verify predictive back preview on Android 14+ from chat, settings and dialogs.

## 8. Verification and release

- [ ] 8.1 Golden test matrix (Settings, Chat, Chats, Home, Cron, error state) × {light, dark, pureBlack} × {blue seed, hermesGold} committed under `test/goldens/`; `flutter test --update-goldens` documented.
- [ ] 8.2 Run `design:accessibility-review`-style audit: 4.5:1 text contrast, 48 dp touch targets, TalkBack labels on composer actions; record results in `docs/FORK.md`.
- [ ] 8.3 Complete `CODE_QUALITY_CHECKLIST.md`, bump version to `2.1.30-you.1`, build split release APKs, publish a GitHub release on the fork; verify the in-app update check sees it.

## Workflow follow-up

- Archive with `openspec archive material-you-redesign` once all tasks are checked.
- Follow-up changes (beads filed): migrate to `material_ui` package; Material 3 Expressive shapes/motion once `material_ui` ships them; propose the theming layer upstream as an opt-in.
