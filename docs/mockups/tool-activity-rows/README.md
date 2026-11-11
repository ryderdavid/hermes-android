# Tool activity as one-line rows: mockups for review

Epic `hmy-h2j`. This is a design pass only. No app code has changed. The
agreed plan is in `openspec/changes/tool-activity-rows/`.

## The problem

`GatewayActivityCard` opens on its own whenever a tool is running
(`_autoExpanded => _hasRunningActivity || verbose`). It then adds a
three-line block for each tool:
- `name: summary`
- `Completed in …`
- `Last observed …`

So every new tool call makes the card taller and pushes the chat text out
of view (01). Those three lines look like detail but can't be tapped, so
they read as noise.

## The proposal (Codex-like, Hermes data)

- **One line per tool, inline with the text.**
  - **Content.** An icon for the kind of tool, then the plain-language
    summary from v2.1.31-you.8 to you.10 (`GatewayToolActivity.summary`).
  - **Styling.** No card. Muted when finished, normal colour with a small
    spinner while running, the danger colour with "Failed:" if it failed.
  - **Height.** Every row is the same height, so adding a tool adds
    exactly one line and nothing above it moves (02).
- **Reasoning becomes a row too.** It shows the reasoning headline
  ("Checking the service binding") with the brain icon, instead of a
  separate expandable card.
- **Rows stay in order with the text.** Tools and the agent's interim
  messages appear in the order they happened, as in Codex. Today's card
  groups them separately.
- **Finished turns fold into "Worked for 2m 24s ›" (03).**
  - **Folded:** only that line and the final answer show.
  - **Tapped (04):** the full sequence returns: rows, interim text, and
    any failures.
  - **Grouping:** runs of the same kind collapse into one row ("Ran 2
    commands").
- **Detail lives in a sheet, not inline.**
  - **Single row (05):** tapping it opens the theme's bottom sheet with
    status and time, the summary, the command in `MarkdownCodeBlock` (wrap
    and copy already built in), and an output excerpt.
  - **Grouped row (06):** opens "Command executions", one entry per
    command, the same way Codex does.
- **What stays from Hermes:**
  - **Data and timestamps:** the same `GatewayToolActivity` data and the
    semantic summaries. Times appear in the sheet.
  - **Behaviour:** tool-id/row-id pinning and recovery.

## Decided after review

- Rows and interim messages stay in time order.
- Finished turns fold automatically.
- Verbose mode does not change rows or folding. It keeps only the message
  metadata lines and is renamed "Show message metadata".
- Real rows are 48dp tall (the tap-target minimum), a little taller than
  drawn here.

## Primitives reused

`GatewayToolActivity` (data, phase, summary, duration, timestamps),
`MessageBubble`, `MarkdownCodeBlock`, the `hermesTheme` bottom sheet, and
`HermesTokens.muted`, `.danger` and `.success`.

New pieces:
- an `ActivityRow` widget of about 40 lines;
- the "Worked for" fold;
- a sheet body.

`buildChatDisplayItems` would emit rows in place of the
`ChatToolActivityGroup` card. That one function is the main change.

## Re-render

```bash
cp docs/mockups/tool-activity-rows/tool_rows_mockup_test.dart.txt \
   test/goldens/zz_tool_rows_mockup_test.dart
flutter test --update-goldens test/goldens/zz_tool_rows_mockup_test.dart
mv test/goldens/mockups/tool_rows/*.png docs/mockups/tool-activity-rows/
rm -r test/goldens/zz_tool_rows_mockup_test.dart test/goldens/mockups
```
