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
   (the version code stays upstream's base; CI checks it).
2. `flutter build apk --release --split-per-abi`.
3. Tag `v<version>` and publish a GitHub release on this fork with the APKs.
   The update check compares `-you.<n>` suffixes, so `2.1.30-you.2` is offered
   to a `2.1.30-you.1` install.

## Accessibility audit

Results of task 8.2 are recorded below.

_Pending._
