# Proposal

## Why

The tool activity card opens itself whenever a tool is running and adds a
three-line block per tool, so every new call makes it taller and pushes
the conversation text out of view. The three lines look like detail but
can't be tapped, so they read as noise. During a live turn, all tool calls
also collect in one card below all the text, out of the order they
happened in.

## What Changes

Mockups: `docs/mockups/tool-activity-rows/` (01 is today, 02–06 are the
proposal).

- **One line per tool, inline, in time order.** Each tool call is a single
  row: an icon for the kind of tool and its plain-language summary. Rows
  and the agent's interim messages appear in the order they happened, both
  live and in history. A new tool adds exactly one line. The
  auto-expanding card is removed.
- **Reasoning becomes a row.** It shows the first line of the reasoning
  next to the brain icon, in place of the expandable reasoning card.
- **Finished turns fold automatically.** When a turn ends, its rows and
  interim messages fold to one "Worked for 2m 24s ›" line above the final
  answer. Tapping it shows the full sequence again, with runs of the same
  kind of tool grouped into one row ("Ran 2 commands").
- **Detail opens in a sheet.** Tapping a row opens a bottom sheet with the
  status, time, summary, command or arguments, and an output excerpt.
  Tapping a grouped row opens one sheet listing each call.
- **Verbose mode no longer affects tools or reasoning.** It keeps only the
  message-metadata lines. The setting is renamed "Show message metadata",
  described as a debugging aid, and moved from the top of Settings to the
  About group. The stored preference is unchanged, so existing backups
  still restore it.

No **BREAKING** changes. No gateway changes.

## Capabilities

### New Capabilities

- `chat-tool-activity`: how tool calls and reasoning appear in a chat:
  rows, their order relative to messages, folding of finished turns,
  grouping, the detail sheet, and what the message-metadata setting does
  and does not change.

### Modified Capabilities

None. `app-theming` already requires tool-activity status to stay
distinguishable in every scheme, and that requirement is unchanged.

## Impact

- **App**:
  - `lib/core/utils/chat_display_items.dart` (emits rows, folds and
    groups in place of `ChatToolActivityGroup` cards and
    `ChatReasoningItem`)
  - `lib/core/screens/chat_screen.dart` (live tool anchoring, list item
    rendering, fold state, verbose wiring)
  - `lib/core/widgets/gateway_activity_card.dart` and
    `GatewayReasoningCard` (removed from the chat)
  - new `lib/core/widgets/activity_row.dart`, `turn_fold.dart` and
    `activity_detail_sheet.dart`
  - `lib/core/services/tool_activity_group_pins.dart` (pins now remember
    which turns the user unfolded or re-folded)
  - `lib/core/screens/settings_screen.dart` and all `lib/l10n/app_*.arb`
- **Tests and goldens**: the three `gateway_activity_card_*` test files
  are replaced by row, fold and sheet tests; `chat_display_items_test.dart`
  is extended; new goldens for rows, the fold and both sheets.
- **Related beads**: `hmy-z97` (live status inside a running tool call) is
  covered by the running row. `hmy-n8v` (prefer the gateway's semantic
  label) feeds the same row label and is unaffected.
- **Coordinator threads** (`hmy-6qr`): its thread view mockup shows the old
  card. It will use these rows once both land; no dependency either way.
