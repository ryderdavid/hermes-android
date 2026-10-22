# Spec Delta

## Purpose

Defines how the app chooses and applies its color scheme, typography and theme mode so it looks like a first-party Android app and follows the user's wallpaper palette.

## ADDED Requirements

### Requirement: Dynamic color by default
On Android 12 or later the app SHALL derive its light and dark color schemes from the system's wallpaper-based palette when the Color setting is *System*. *System* SHALL be the default for new installs.

#### Scenario: Pixel with wallpaper palette
- **WHEN** the app launches on Android 12+ with Color set to *System*
- **THEN** primary, secondary, tertiary, surface and container roles match the system dynamic palette

#### Scenario: Wallpaper changes while app is running
- **WHEN** the user changes wallpaper or system palette and returns to the app
- **THEN** the app's colors update without a restart

### Requirement: Seeded fallback below Android 12
When dynamic color is unavailable the app SHALL generate a full Material 3 tonal scheme from a seed color, and the Color setting SHALL hide or disable the *System* option.

#### Scenario: Android 11 device
- **WHEN** the app launches on Android 11 with no saved Color choice
- **THEN** the app uses the default seeded scheme and the Color setting shows *System* as unavailable

### Requirement: User-selectable color source
The Settings screen SHALL offer a Color choice of *System*, *Hermes gold*, and at least four preset seed colors. Selecting one SHALL apply immediately and persist across restarts and app backups.

#### Scenario: Choosing Hermes gold
- **WHEN** the user selects *Hermes gold*
- **THEN** the whole app re-themes to a tonal scheme seeded from `#D4AF37` with no restart, and the choice survives an app restart

### Requirement: Theme mode and pure black
The app SHALL honour Light, Dark and System theme modes. An optional *Pure black* toggle SHALL set dark-mode background and surface to `#000000` while keeping container roles tonal.

#### Scenario: Pure black in dark mode
- **WHEN** theme mode resolves to dark and *Pure black* is on
- **THEN** screen backgrounds are true black and cards, fields and sheets remain distinguishable surface containers

### Requirement: No hardcoded UI colors
Every color rendered by app widgets SHALL come from the active color scheme or a semantic color harmonized to it. Status meanings (success, warning, error, tool activity) SHALL remain distinguishable in every scheme.

#### Scenario: Gold no longer leaks into a dynamic theme
- **WHEN** Color is *System* and the wallpaper palette is blue
- **THEN** no screen, button, chip, badge or icon renders the upstream gold accent

#### Scenario: Error stays recognisable
- **WHEN** an error state renders under any color choice
- **THEN** it uses the scheme's error roles and meets 3:1 contrast for icons and 4.5:1 for text

### Requirement: Material 3 component sizing
Buttons SHALL use Material 3 sizes (40 dp default height, 48 dp minimum touch target) and the Filled / Tonal / Outlined / Text hierarchy, with at most one Filled button per view.

#### Scenario: Error state retry
- **WHEN** a screen fails to load
- **THEN** it shows an icon, title, supporting text and a single standard-height tonal or filled Retry button, not an oversized pill

### Requirement: System typography
Body and UI text SHALL use the Material 3 type scale in the platform default sans-serif, honour the system font-size setting, and not use the Cinzel display face outside the app wordmark.

#### Scenario: Large font setting
- **WHEN** the system font scale is 1.3
- **THEN** text scales accordingly and no list row, button or composer clips its label

### Requirement: Edge-to-edge system bars
The app SHALL draw edge-to-edge with transparent status and navigation bars whose icon contrast follows the active theme.

#### Scenario: Gesture navigation
- **WHEN** the device uses gesture navigation
- **THEN** content scrolls behind the gesture handle area and interactive controls are inset above it

### Requirement: Predictive back
The app SHALL opt in to Android predictive back so a back gesture previews the destination before committing, on every route that supports back.

#### Scenario: Back from a chat
- **WHEN** the user starts a back swipe inside a chat on Android 14+
- **THEN** the system shows the predictive back preview and releasing the swipe returns to the chat list
