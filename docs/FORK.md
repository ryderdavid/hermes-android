# Hermes — Material You fork

This repository (`ryderdavid/hermes-android`) is a fork of
[`rusty4444/hermes-android`](https://github.com/rusty4444/hermes-android). It
keeps every upstream feature and re-skins the app as a first-party-looking
Material You app: wallpaper-based dynamic color, M3 component sizing, a
Messages-style composer and Pixel-style Settings. The design and task list
live in `openspec/changes/material-you-redesign/`.

## Identity on the device

| | Upstream | This fork |
|---|---|---|
| Release application id | `com.hermesagent.hermes_android` | `com.ryderdavid.hermes_you` |
| Debug application id | `….hermes_android.dev` | `com.ryderdavid.hermes_you.dev` |
| Launcher label | Hermes Agent | Hermes (debug: Hermes Dev) |
| Update check | upstream releases | this fork's releases |

Because the ids differ, the fork installs beside upstream and each app keeps
its own connections and settings. Move settings across with Settings →
Backup & restore (the encrypted config backup). The Kotlin namespace and the
platform channel names stay upstream's to keep rebases small; the launcher
shortcut pins its intent to the fork's package so it never opens upstream.

The in-app update check (`AppUpdateService.releasesApiUrl`) reads
`ryderdavid/hermes-android` releases only. Upstream APKs are signed with a
different key and use a different id, so they could never upgrade the fork.

## Staying current with upstream

```bash
scripts/sync-upstream.sh            # fetch, fast-forward main, rebase, analyze, test
scripts/sync-upstream.sh --push     # …then push main and force-push the branch (with lease)
```

The script refuses to run with uncommitted changes or if local `main` has
diverged from `upstream/main`. Conflicts are rare by construction: colors are
decided in `lib/core/theme/hermes_theme.dart`, component styling is set once
in `hermesTheme`, and call-site edits are mostly deletions. The two files
upstream churns most (`chat_screen.dart`, `main.dart`) are touched only where
a widget was extracted (`lib/core/widgets/chat_composer.dart`) or a color
replaced by a scheme role.

After a rebase, re-run the golden tests; an upstream layout change shows up
there first:

```bash
flutter test test/goldens
flutter test --update-goldens test/goldens   # only after checking the diff is intended
```

## Releasing

1. Bump `version:` in `pubspec.yaml` to `<upstream version>-you.<n>+<code>`
   (the version code stays upstream's base; CI checks it) and the matching
   expectation in `test/release_identity_test.dart`. After a rebase these two
   lines conflict whenever upstream bumps its version: take upstream's
   version and re-append `-you.1`.
2. `flutter build apk --release --split-per-abi`. Gradle signs with the key
   named in the repo-root `key.properties` (gitignored). The fork's key is
   `~/.android/hermes-you-release.jks`, alias `hermes_you`; **back up the
   keystore and its password** (they are in `key.properties`): every later
   release must use the same key or installs cannot update.
3. Write notes in `docs/releases/v<version>.md` (upstream's `CHANGELOG.md`
   is left alone so rebases stay clean), tag `v<version>` and publish a GitHub
   release on this fork with the APKs. Upstream's `release.yml` only runs in
   `rusty4444/hermes-android`. The update check compares `-you.<n>`
   suffixes, so `2.1.30-you.2` is offered to a `2.1.30-you.1` install.

## Accessibility audit

Audited 2026-10-23 for task 8.2 with Flutter's Android guideline matchers
(`test/accessibility_guidelines_test.dart`), which CI runs with the rest of
the suite. Screens: chat composer, a loaded chat, the Chats list, Settings
and the Cron error state, each in light and dark with the fallback blue and
Hermes gold schemes.

| Check | Rule | Result |
|---|---|---|
| Text contrast | 4.5:1 body text, 3:1 large text (`textContrastGuideline`) | Pass |
| Touch targets | 48 × 48 dp (`androidTapTargetGuideline`) | Pass |
| TalkBack labels | every tappable node labelled (`labeledTapTargetGuideline`) | Pass |
| Composer labels | Choose chat model, Spoken replies, Add attachment, Message, Start voice input, Send message | Pass |
| Bubble and status colors | 4.5:1 for every seed, light and dark (`widget_test.dart`, `hermes_theme_test.dart`) | Pass |

Found and fixed during the audit:

- Refresh buttons on Cron, Memory, Skills and the session list, the Files
  back button and the media viewer's close button had no label; they now
  carry tooltips (which TalkBack reads).
- The code block's wrap and copy buttons were wrapped in a `Tooltip` that
  TalkBack did not read as a label; the tooltip moved onto the buttons.
- The theme-mode segmented button was 40 dp with no padded touch target; it
  now has a 48 dp target.
- Status chips ("Done", "Needs you") drew 12 sp text at 3.6:1 on their tinted
  fill; the text is now darkened toward on-surface just enough for 4.5:1.

Not covered by automated checks: TalkBack reading order and live regions on a
real device, and themed-icon, splash and predictive-back behaviour on Android
13+/14+ (beads labelled `needs-device-check`).
