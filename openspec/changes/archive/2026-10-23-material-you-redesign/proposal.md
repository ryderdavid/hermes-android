# Proposal: Material You redesign

## Why

The app is functionally excellent but visually reads as a branded port rather than an Android app: a fixed gold-on-black palette (`#D4AF37`), oversized pill buttons that dwarf the text fields beside them, and a Cinzel display face. On a Pixel running Android 12+ it ignores the user's wallpaper palette, which is the single strongest signal of a "native" Android app. This fork re-skins the client so it looks and behaves like a first-party Google app (Phone, Messages, Settings) while keeping every upstream feature and staying cheap to rebase onto `rusty4444/hermes-android`.

## What Changes

- Adopt Material You dynamic color: the app's `ColorScheme` is derived from the system wallpaper palette on Android 12+, with a neutral seeded fallback below that.
- Add an **Appearance → Color** setting: *System (dynamic)*, *Hermes gold* (the upstream palette, seeded), and a small set of seed colors; plus an optional *Pure black* dark mode.
- Replace all hardcoded colors with `ColorScheme` roles and a small set of harmonized semantic extensions (success, warning, tool-activity, code surfaces).
- Rebuild the chat composer as a Messages-style input: one rounded `surfaceContainerHigh` field with inline attach/mic actions and a 48 dp send button that is never taller than the field.
- Normalize buttons to M3 sizing (40 dp height, Filled / Tonal / Outlined / Text hierarchy) and replace ad-hoc error panels with a shared M3 error/empty state.
- Restyle Settings into Pixel-style grouped lists (section headers in `primary`, `ListTile`s in rounded `surfaceContainer` groups) and use M3 `NavigationBar`, `TopAppBar` (large/collapsing where appropriate), `SegmentedButton`, `Switch`, dialogs and sheets throughout.
- Use the system type scale (Roboto by default, optional bundled Google Sans Flex); Cinzel is retained only for the wordmark on onboarding.
- Android platform polish: themed (monochrome) launcher icon, Android 12 splash using dynamic colors, edge-to-edge with transparent system bars, predictive back.
- Fork identity: distinct `applicationId` so the fork installs beside upstream, and the in-app update check points at the fork's GitHub releases.
- **BREAKING (fork only)**: the default look changes from gold/black to dynamic color. *Hermes gold* remains one tap away.

## Capabilities

### New Capabilities

- `app-theming`: how the app derives its color scheme (dynamic, seeded, fallback), honours theme mode and contrast, and exposes theme choices to the user.
- `chat-composer`: the visual and interaction contract of the message input bar (sizing, actions, states, keyboard behaviour).
- `fork-distribution`: how the fork identifies itself on device (package ID, name, icon) and where it checks for updates.

### Modified Capabilities

- None. `openspec/specs/` is empty in this repository; upstream behaviour is the implicit baseline.

## Impact

- **Code**: new `lib/core/theme/` module; edits to `main.dart` (MaterialApp wiring), settings screen, chat composer, shared error/empty widgets, and every widget currently using hardcoded colors. No changes to Gateway/Dashboard networking, models, or storage beyond new theme preferences.
- **Dependencies**: adds `dynamic_color` (^1.9.0 — 2.x requires the standalone `material_ui` package, see design D9). Optional font asset (Google Sans Flex, OFL).
- **Android**: `android/app/build.gradle.kts` (applicationId), `res/` (monochrome icon, splash theme), `AndroidManifest.xml` (predictive back).
- **Tests**: golden tests per screen in light/dark × dynamic/gold; existing widget tests that assert gold colors must be updated.
- **Upstream sync**: changes are concentrated in the theme module and a short list of widgets to keep rebases tractable.
