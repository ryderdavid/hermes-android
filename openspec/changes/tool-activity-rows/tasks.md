# Tasks

Bead epic `hmy-h2j`; group N is bead TR-N (`hmy-h2j.2` to `hmy-h2j.6`).
Design references (D1–D10) are in design.md.

## 1. Projection: turns, order, fold and grouping

- [x] 1.1 Rework `buildChatDisplayItems` to collect each turn (user
  message, ordered steps, final answer) and flatten it per D1, emitting
  `ChatActivityStep`, `ChatActivityGroupItem` and `ChatTurnFold` items in
  place of `ChatToolActivityGroup` and `ChatReasoningItem`. Drop the
  `verbose` parameter. Verify by extending `test/chat_display_items_test.dart`:
  folded, unfolded, running, no-final-answer and plain-reply turns.
- [x] 1.2 Anchor live tool activities to a message position (D2): record
  the anchor at `tool.start`, seal a still-streaming message through the
  interim-boundary path, and place unstored activities after their anchor.
  Verify with tests for text → tool → text, tool before any text, and
  handoff to stored order after a history refresh.
- [x] 1.3 Add reasoning rows (D3): label from the first usable line with
  the "Thinking" fallback. Verify with unit tests for a headline, a
  markdown-emphasised headline, and empty or punctuation-only first lines.
- [x] 1.4 Compute the fold line (D4): duration from stored timestamps or
  observed turn times, step count when unknown, failure marker. Verify
  with unit tests for each case.
- [x] 1.5 Add grouping (D5) as a pure function: same-kind successful runs
  group, failures and reasoning never do, running turns are never grouped.
  Verify with unit tests, including a failure in the middle of a run.

## 2. Row, fold and sheet widgets

- [x] 2.1 Build `ActivityRow` (D7) in `lib/core/widgets/activity_row.dart`:
  running, completed and failed states, 48dp minimum height, merged
  semantics. Verify with widget tests for each state and its semantics
  label, and add it to `test/accessibility_guidelines_test.dart`.
- [x] 2.2 Build `TurnFoldLine` in `lib/core/widgets/turn_fold.dart`:
  duration or step count, failure marker, chevron state. Verify with
  widget tests for each variant and tap callback.
- [x] 2.3 Build `ActivityDetailSheet` (D8) in
  `lib/core/widgets/activity_detail_sheet.dart`: single-call and group
  layouts, command and output in `MarkdownCodeBlock`, 4 KB output cut,
  absent fields omitted, reasoning text selectable. Verify with widget
  tests for a live call, a stored call with and without detail, a group,
  and reasoning.
- [x] 2.4 Add the strings (row state labels, fold line, group labels,
  sheet headings, "Thinking") to every `lib/l10n/app_*.arb` catalogue and
  run `flutter gen-l10n`. Verify `flutter analyze` reports no issues and
  `tools/check_no_hardcoded_colors.sh` passes.
- [x] 2.5 Add goldens across the matrix: `activity_rows_running`,
  `activity_rows_folded`, `activity_rows_unfolded`,
  `activity_detail_sheet`, `activity_group_sheet`. Verify with
  `flutter test test/goldens`.

## 3. Chat screen wiring

- [x] 3.1 Render the new items in `ChatScreen`'s list builder and open the
  sheet on row tap. Verify with a widget test that tapping a row opens the
  sheet and that closing it leaves the draft and scroll offset unchanged.
- [x] 3.2 Rename `ToolActivityGroupPins` to `TurnFoldPins` keyed by turn
  id with live-to-stored aliasing (D6), and fold a turn when it settles
  with a final answer. Verify with tests that a choice survives scrolling
  the turn off screen and a history refresh, and that the final answer is
  visible after the automatic fold.
- [x] 3.3 Verify no-jump behaviour: a widget test that, with the list
  scrolled away from the end, adding five tool activities leaves the first
  visible item's position unchanged. Extend
  `test/chat_history_scroll_test.dart`.
- [x] 3.4 Delete `GatewayActivityCard`, `GatewayReasoningCard` and the
  three `gateway_activity_card_*` test files (D10); update
  `tool_card_summary_demo_test.dart` and `gateway_insight_test.dart` to
  the new widgets. Verify `flutter analyze` and the full `flutter test`
  pass with no references left (`grep -r GatewayActivityCard lib test`
  returns nothing).

## 4. Message-metadata setting

- [x] 4.1 Narrow verbose to message metadata (D9): remove it from the
  projection and the deleted cards, keep it on `MessageBubble`. Verify
  with a test that a finished turn's items are identical with the
  preference on and off, and that metadata lines still appear when on.
- [x] 4.2 Move the toggle to the About group as "Show message metadata"
  with a debugging subtitle; replace the old strings in every catalogue;
  keep the `verbose_mode` key. Verify with a settings widget test for
  position and label, and with the existing backup round-trip test.

## 5. Verification and release

- [ ] 5.1 Run `flutter analyze`, the full `flutter test`, the colour lint
  and `flutter build apk --debug`. On the phone (`needs-device-check`):
  run a long tool-heavy turn while reading earlier text, confirm nothing
  jumps, the turn folds when it ends, unfolding shows the right order, and
  both sheets open. Record the result in the bead.
- [ ] 5.2 Bump to the next `-you.<n>`, write `docs/releases/v<version>.md`,
  then build, tag and publish per `docs/FORK.md`. Verify the in-app update
  check offers it. Close `hmy-z97` as covered by the running row.

## Workflow follow-up

- Archive this change with `/opsx:archive` after 5.2 and sync
  `chat-tool-activity` into `openspec/specs/`.
