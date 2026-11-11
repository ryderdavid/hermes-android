# Design

## Context

See proposal.md for motivation and `docs/mockups/tool-activity-rows/` for
the target screens. What exists today:

- **Projection.** `buildChatDisplayItems`
  (`lib/core/utils/chat_display_items.dart`) turns the message list into
  list items. Stored tool-result messages consume `toolActivities` in
  order and become a `ChatToolActivityGroup` between the messages around
  them, so history is already in time order.
- **Live turns are not in order.** Tool events land in a flat
  `_toolActivities` list with no position (`_upsertToolProgress`). Until
  the server stores them, the builder appends them all as one trailing
  card below every message. Interim text is sealed into its own assistant
  message by `message.interim` (`GatewayInterimTransition`).
- **The card.** `GatewayActivityCard` opens itself while any activity is
  running (`_autoExpanded => _hasRunningActivity || verbose`) and draws
  three lines per tool.
- **Reasoning.** Stored on the assistant message as `_gateway_reasoning`
  and emitted as a `ChatReasoningItem` before that message's bubble. The
  reasoning text has no headline field.
- **Expansion memory.** `ToolActivityGroupPins` keeps the user's
  open/closed choice per group id, with aliases from a live tool id to the
  stored row id, because list items are rebuilt at other indexes and
  evicted when off screen.
- **Tool data.** A live `GatewayToolActivity` carries `summary`, `detail`
  (the command), `durationSeconds` and observed times. One rebuilt from a
  stored result carries only the summary and the result time.
- **Verbose.** The `verbose_mode` preference is read in three places: the
  card's auto-expand, the reasoning item's initial expansion, and
  `MessageBubble`'s metadata lines. Its toggle sits under Appearance at the
  top of Settings.

## Goals / Non-Goals

**Goals:**
- Keep the chat a flat, lazily built list. Folding and grouping happen in
  the projection, not inside a widget that changes height.
- Reuse `GatewayToolActivity`, the semantic summaries, `MarkdownCodeBlock`
  and the theme's bottom sheet.
- Keep `chat_screen.dart` edits to hook points.

**Non-Goals:**
- Gateway changes. Everything is derived from data the app already gets.
- A persisted fold state across app restarts. Choices last while the chat
  is open, as pins do today.
- Changing the turn status bar above the composer or the subagent card.

## Decisions

**D1. The projection groups items by turn, then flattens.** The builder
first collects each turn as: the user message, an ordered list of steps
(tool rows, reasoning rows, interim messages), and the final answer if
there is one. A second pass turns each turn into flat list items using the
fold state:
- folded: user message, one `ChatTurnFold` item, final answer;
- unfolded: user message, `ChatTurnFold`, each step (grouped per D5),
  final answer;
- running or no final answer: user message, each step ungrouped.

*Alternative:* one expandable widget per turn holding its steps. Rejected:
it is the same shape as today's card, and a tall item that changes height
is what makes the list jump.

**D2. Live tools are anchored to a message position.** When a tool starts,
the activity records which assistant message it follows (the index of the
last assistant message that has text). The builder places an unstored
activity after that message instead of at the end. If that message is
still streaming when the tool starts, the app seals it through the
existing interim-boundary path, so later text starts a new message below
the row. Once the server stores the tool result, the stored order takes
over, as today.
*Alternative:* order by timestamps. Rejected: streamed text has no
per-chunk time, and stored results from older gateways have none either.

**D3. Reasoning rows.** A reasoning row's label is the first non-empty
line of the reasoning text with markdown emphasis markers removed, cut to
one line. If that yields nothing, the label is the localized "Thinking".
The row sits where the `ChatReasoningItem` sits today (before its
message). Tapping it opens the detail sheet with the full text in a
`SelectionArea`.

**D4. Fold line content.** Duration is the final answer's timestamp minus
the user message's timestamp for stored turns, and observed turn start to
turn end for a turn that finished in this session. If either end is
missing, the line reads as a step count. A turn with any failed step adds
a failure marker in `HermesTokens.danger`.

**D5. Grouping is a pure function.** Inside an unfolded finished turn,
consecutive successful steps with the same tool name and no message
between them become one group item. Failed steps and reasoning rows are
never grouped. Group labels come from a per-kind plural string ("Ran {n}
commands", "Read {n} files"), with a generic fallback ("Used {tool} {n}
times").

**D6. Fold state reuses the pin store.** `ToolActivityGroupPins` is
renamed `TurnFoldPins` and keyed by turn id: the stored id of the turn's
user message, or the first step's identity while live, aliased to the
stored id on handoff exactly as tool ids are aliased today. `null` means
the default (folded when finished), `true` unfolded, `false` folded by
hand.

**D7. Row widget.** `ActivityRow` is a full-width `InkWell` with a 48dp
minimum height, a 20dp icon or progress indicator, and one ellipsized
line. It has merged semantics: kind, summary, state, and a button role.
The mockups draw rows about 34dp tall; the real rows are 48dp so they pass
the tap-target check in `test/accessibility_guidelines_test.dart`.
*Alternative:* 36dp rows with overlapping hit areas. Rejected: it fails
that check and makes mis-taps likely.

**D8. Detail sheet data is fetched on open.** For a live activity the
sheet uses the fields it already has (`detail`, `durationSeconds`, times).
For a stored one, it reads the arguments from the assistant message's tool
call and the output from the stored tool-result message at the moment the
sheet opens. Output is cut to 4 KB with a "truncated" note. Nothing extra
is kept on display items. Fields that are absent are left out.
*Alternative:* carry args and output on every `GatewayToolActivity`.
Rejected: it holds large strings in memory for every row in a long chat.

**D9. Verbose is narrowed, not removed.**
- `buildChatDisplayItems` drops its `verbose` parameter.
- `MessageBubble` keeps its `verbose` parameter for the metadata lines.
- The `verbose_mode` preference key and its backup entry are unchanged.
- The toggle moves from the preferences group to the About group, with
  the title "Show message metadata" and a subtitle saying it is for
  debugging. The old strings `verbose_mode` and
  `show_tool_calls_thinking_and_message_metadata` are replaced in every
  catalogue.

**D10. Removal.** `GatewayActivityCard` and `GatewayReasoningCard` are
deleted along with their three card test files once the rows are in.
`GatewaySubagentCard` and `GatewayNoticeCard` stay.

## Risks / Trade-offs

- **Sealing a streaming message when a tool starts (D2) could disturb
  completion handling** → It goes through the same
  `_gateway_interim_boundary` path that `message.interim` uses, which
  `_completionAssistantMessage` already handles. Tests cover: text, tool,
  more text; tool before any text; and recovery after a reconnect
  mid-turn.
- **Folding at turn end shrinks the list above the answer** → The fold is
  applied in the same frame as the final message settles, and the existing
  streaming-follow keeps the end in view. A test asserts the final answer
  is visible after the fold.
- **Reasoning first lines can be poor labels** → Fall back to "Thinking"
  when the first line is empty or only punctuation. The full text is one
  tap away.
- **Stored calls from older gateways have no command or output** → The
  sheet omits those sections (spec scenario), and the row still shows the
  summary.
- **Upstream churn** → New widgets live in new files. The builder change
  is contained in `chat_display_items.dart`, which upstream also edits, so
  rebases of that file will need care. The existing builder tests are
  extended, not replaced, to catch drift.

## Migration Plan

One release. No data migration: the preference key is unchanged and fold
state is in memory only. Rollback is reverting the change; nothing is
written in a new format.

## Open Questions

- The exact per-kind group labels beyond commands and file reads can be
  settled while writing the strings.
