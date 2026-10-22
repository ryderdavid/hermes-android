# Spec Delta

## Purpose

Defines how the Material You fork identifies itself on a device and where it looks for updates, so it can be installed beside the upstream app without either one overwriting or nagging the other.

## ADDED Requirements

### Requirement: Side-by-side install
The fork SHALL use an Android application ID distinct from upstream for both release and debug builds, and a distinct launcher label.

#### Scenario: Both apps installed
- **WHEN** the upstream APK and the fork APK are installed on the same phone
- **THEN** both appear in the launcher and each keeps its own connections and settings

### Requirement: Fork update channel
The in-app update check SHALL query the fork's own GitHub releases, and the About section SHALL identify the build as the fork and link to its repository and to upstream.

#### Scenario: Upstream publishes a release
- **WHEN** upstream publishes a newer version than the fork's latest release
- **THEN** the fork does not prompt the user to install the upstream APK

### Requirement: Themed launcher icon
The launcher icon SHALL provide a monochrome layer so Android 13+ can tint it with the user's theme when themed icons are enabled.

#### Scenario: Themed icons on
- **WHEN** the user enables themed icons on a Pixel
- **THEN** the fork's icon renders tinted in the system palette like first-party apps

### Requirement: Themed launch splash
On Android 12+ the launch splash SHALL use the platform splash screen with a background matching the system theme and the monochrome app glyph.

#### Scenario: Cold start in dark mode
- **WHEN** the app cold-starts with the system in dark mode
- **THEN** the splash shows a dark background with the app glyph and no white flash before the first frame
