# Project detail "Chats" tab, redrawn in the new app style: mockup for review

Design pass only — no app code has changed. The screenshot under review is
the legacy project-detail chats list (plain rows, no marks): the Chats tab of
`ProjectDetailScreen` (`lib/core/widgets/project_detail_screen.dart`), which
still renders `_SessionCard` rows while the main Chats destination
(`WorkspaceSessionsScreen`) already uses the new workspace style.

## The proposal

Restyle the project's Chats tab to match `WorkspaceSessionsScreen`:

- **Rows become `HermesCard`s with a `ChatMark`** — an expressive polar blob
  (`ExpressiveShape.chatMarks`, hash-picked per session id) holding the topic
  icon; a running chat's mark morphs through `morphSequence` (the same busy
  animation as the chat app bar, now also in list rows).
- **Tonal `StatusChip`** (Running / Done) plus relative time, as on the main
  Chats list.
- **Connected filter segment** (All / Recent / Unassigned / Archived) and
  **date group headers** (Today / Earlier) via `SegmentedListGroup`.
- **M3E extended FAB** ("+ New chat", `primaryContainer`, 16dp radius)
  instead of the old FAB.
- App bar keeps back + title but gains the project's `ChatMark` next to the
  overflow menu.

## Files

- `index.html` — self-contained mockup (inline CSS/JS; blob paths generated
  with the same polar formula as `lib/core/expressive/shapes.dart`; the
  running row's mark animates through the morph sequence).
- `01_project_chats_new_style.png` — headless render check (browser_exec),
  412x892 phone canvas, light theme, blue seed `0xFF4285F4`.
