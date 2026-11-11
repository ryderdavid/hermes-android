# hermes-android OpenSpec + beads conventions

## CLI flags that actually work

- Scaffold: `openspec new change <kebab-name>` (schema comes from `openspec/config.yaml`, spec-driven here).
- Progress: `openspec status --change <name> [--json]` — "4/4 artifacts complete" means planning is done.
- Validation: `openspec validate <name>` — the name is positional. Passing `--change` fails with "unknown option '--change'"; that flag exists only on `status`/`instructions`.
- The validator emits warnings (not errors) when a Requirement's text exceeds ~500 chars — split it into one-behavior requirements and move detail into `#### Scenario` WHEN/THEN blocks.

## Artifact format (mirror the existing `openspec/changes/*` entries)

- `proposal.md`: `## Why`, `## What Changes`, `## Capabilities` (New / Modified), `## Impact` (files touched, l10n keys, cross-repo contracts).
- `design.md`: `## Context`, `## Goals` / `## Non-goals`, `## Decisions` (D1…Dn with rationale and rejected alternatives), `## Architecture` (small ascii flow), `## Security considerations`, `## Testing`, `## Open questions`.
- `tasks.md`: numbered sections with `- [ ]` items, each item ending in "Verify with …" naming the concrete command or output that proves it.
- `specs/<capability>/spec.md`: `# Spec Delta`, `## Purpose`, `## ADDED Requirements` with `### Requirement:` + `#### Scenario:` blocks. A new capability is a new directory under the change's `specs/`; it only lands in `openspec/specs/` at archive + sync time.

## Grounding before writing

- Read the actual code the change touches and cite `file:line` in design.md (line numbers drift — the apply phase re-reads anyway).
- Check `pubspec.yaml` for existing dependencies and `android/app/src/main/AndroidManifest.xml` for permissions before assuming either is present.

## Branching and git

- Feature work on a dedicated branch. `git checkout -b feat/<slug>` carries uncommitted changes over — keep unrelated WIP out of the feature's commits.
- Do not commit or push unless asked (conservative profile in AGENTS.md).

## Beads for a change

- Epic: `bd create --title=... --description=... --type=feature --priority=2`.
- Children mirroring tasks.md sections: `bd create ... --parent=<epic-id>`; capture the ids with `--json` (grep `"id"`), then chain execution order with `bd dep add <child> <previous-child>`.
- Put the change directory and branch name in the epic description so a worker can orient without the transcript.
- Never use `bd edit` — it opens `$EDITOR` and blocks the agent.
