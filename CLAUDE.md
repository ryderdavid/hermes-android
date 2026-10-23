# Project Instructions for AI Agents

This file provides instructions and context for AI coding agents working on this project.

<!-- BEGIN BEADS INTEGRATION v:1 profile:minimal hash:1105d646 -->
## Beads Issue Tracker

This project uses **bd (beads)** for issue tracking. Run `bd prime` to see full workflow context and commands.

### Quick Reference

```bash
bd ready              # Find available work
bd show <id>          # View issue details
bd update <id> --claim  # Claim work
bd close <id>         # Complete work
```

### Rules

- Use `bd` for ALL task tracking — do NOT use TodoWrite, TaskCreate, or markdown TODO lists
- Run `bd prime` for detailed command reference and session close protocol
- Use `bd remember` for persistent knowledge — do NOT use MEMORY.md files

**Architecture in one line:** issues live in a local Dolt DB; sync uses `refs/dolt/data` on your git remote; `.beads/issues.jsonl` is a passive export. See https://github.com/gastownhall/beads/blob/main/docs/core-concepts/sync-concepts.md for details and anti-patterns.

## Agent Context Profiles

The managed Beads block is task-tracking guidance, not permission to override repository, user, or orchestrator instructions.

- **Conservative (default)**: Use `bd` for task tracking. Do not run git commits, git pushes, or Dolt remote sync unless explicitly asked. At handoff, report changed files, validation, and suggested next commands.
- **Minimal**: Keep tool instruction files as pointers to `bd prime`; use the same conservative git policy unless active instructions say otherwise.
- **Team-maintainer**: Only when the repository explicitly opts in, agents may close beads, run quality gates, commit, and push as part of session close. A current "do not commit" or "do not push" instruction still wins.

## Session Completion

This protocol applies when ending a Beads implementation workflow. It is subordinate to explicit user, repository, and orchestrator instructions.

1. **File issues for remaining work** - Create beads for anything that needs follow-up
2. **Run quality gates** (if code changed) - Tests, linters, builds
3. **Update issue status** - Close finished work, update in-progress items
4. **Handle git/sync by active profile**:
   ```bash
   # Conservative/minimal/default: report status and proposed commands; wait for approval.
   git status

   # Team-maintainer opt-in only, unless current instructions forbid it:
   git pull --rebase
   git push
   git status
   ```
5. **Hand off** - Summarize changes, validation, issue status, and any blocked sync/commit/push step

**Critical rules:**
- Explicit user or orchestrator instructions override this Beads block.
- Do not commit or push without clear authority from the active profile or the current user request.
- If a required sync or push is blocked, stop and report the exact command and error.
<!-- END BEADS INTEGRATION -->


## Build & Test

Flutter **3.44.0** (the version upstream CI pins). Run from the repo root:

```bash
flutter pub get
flutter analyze                         # must report "No issues found!"
flutter test                            # full suite, ~1 min
flutter test test/goldens               # golden images only
flutter test --update-goldens test/goldens   # regenerate after an intended visual change
flutter gen-l10n                        # after editing lib/l10n/app_*.arb
flutter build apk --debug               # installs as com.ryderdavid.hermes_you.dev
tools/check_no_hardcoded_colors.sh      # no Color(0x…)/Colors.* outside the theme module
scripts/sync-upstream.sh                # rebase onto rusty4444/hermes-android, then analyze + test
```

- Run `dart format` on the files you touched only. Upstream is not formatted
  with the current formatter, and a tree-wide format makes rebases conflict.
- User-visible strings go in all `lib/l10n/app_*.arb` catalogues (en, de, es,
  fr, ja, ko, pt, pt_BR, ru, zh, zh_Hans), then `flutter gen-l10n`; the
  generated `app_localizations*.dart` files are committed.

## Architecture Overview

Flutter client for a Hermes Agent gateway (chat over WebSocket, dashboard REST
on :9119). This repository is a **fork** of `rusty4444/hermes-android` that
re-skins it as a Material You app; see `docs/FORK.md` and
`openspec/changes/material-you-redesign/`.

- `lib/main.dart` — app root (`HermesApp`), `DynamicColorBuilder` +
  `appearanceSelection` drive the theme; `HomeScreen` and the shell.
- `lib/core/theme/hermes_theme.dart` — the only place colors are decided:
  `hermesColorScheme` (wallpaper, seed or fallback; pure black),
  `HermesTokens` (tokens derived from the scheme) and `hermesTheme`
  (component themes).
- `lib/core/services/` — connections, gateway turn coordination, preferences
  (`appearance_preferences.dart`, `text_size_preference.dart`, …), backup,
  update checks (fork releases).
- `lib/core/screens/` — full screens (chat, settings, cron, sessions, …);
  `lib/core/widgets/` — shared widgets (`hermes_components.dart`,
  `settings_group.dart`, `chat_composer.dart`, shell).
- `android/` — Kotlin `MainActivity` (share/launch/keep-alive channels),
  manifest, launcher icon and splash resources.
- `test/` — unit and widget tests; `test/goldens/` holds the golden matrix
  with its own `flutter_test_config.dart` (real fonts, small tolerance).

## Conventions & Patterns

- Colors come from `Theme.of(context).colorScheme` or `HermesTokens.of(context)`;
  never hardcode `Color(0x…)` or `Colors.*` outside `lib/core/theme/`.
- Set component styling once in `hermesTheme`; delete per-call-site styling
  rather than rewriting it, to keep upstream rebases cheap.
- Track work in beads (`bd`) and tick the matching task in
  `openspec/changes/material-you-redesign/tasks.md`
  (`.beads/openspec-map.json` maps task numbers to bead ids). Label checks that
  need a phone `needs-device-check`.
