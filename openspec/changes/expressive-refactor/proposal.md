# Proposal: Material 3 Expressive front-end refactor

## Why

The Material You fork (v2.1.30-you.2) follows Material 3 as Flutter 3.44 ships it: baseline components with dynamic color. Pixel apps on Android 16 have since moved to Material 3 Expressive — a shape library, segmented grouped lists, emphasized type, spring motion, connected button groups, split buttons, a shorter navigation bar and a loading indicator that morphs. Next to them Hermes reads as an older Material app. The approved design (canvas "Hermes Expressive") rebuilds the front end in that language.

## What Changes

- An in-repo **expressive kit** (`lib/core/expressive/`): expressive shapes and shape marks, spring motion tokens, a shape loading indicator, wavy progress, segmented list groups and tiles, a connected button group and a split button.
- **Theme**: emphasized type styles, the extended corner scale, a 64dp navigation bar, segmented list defaults, M3E FAB sizes, sheet and dialog shapes.
- **Home**: a search bar at the top, a "Needs you" carousel of approval/running cards, recent chats in a segmented list with project shape marks.
- **Chats**: a large title header, a connected button group for filters, chats grouped by day in segmented lists with status labels.
- **Chat**: a shape avatar and the model as a tappable app bar subtitle; Hermes replies as full-width prose without bubbles; one tool-activity card per turn; the shape loading indicator while working; a composer of `+`, a pill field with dictation, and a Send button that morphs into a square Stop. Spoken replies move to the chat overflow menu.
- **Approval**: a modal bottom sheet with the command in a code block, Deny, and a split "Approve once" button whose menu holds the broader choices.
- **Settings**: a large header, a connection card and grouped segmented rows with tonal icons; appearance moves to a "Color & theme" page with a connected theme group and shape swatches.
- Other panes (Projects, Activity, More) adopt segmented lists.

## Capabilities

### New Capabilities

- `expressive-components`: the shape, motion, list and button primitives every screen builds on.

### Modified Capabilities

- `app-theming`: emphasized typography, extended corner scale, 64dp navigation bar.
- `chat-composer`: secondary controls leave the input row; Send/Stop morph.

## Impact

- **Code**: new `lib/core/expressive/`; restyles in `hermes_theme.dart`, `home_pane.dart`, `workspace_sessions_screen.dart`, `workspace_screen.dart`, `projects_pane.dart`, `activity_pane.dart`, `more_pane.dart`, `chat_screen.dart` (app bar and bubble only), `chat_composer.dart`, `gateway_approval_dialog.dart`, `settings_screen.dart`, a new `appearance_screen.dart`.
- **No** networking, storage, turn or recovery changes. Keys, tooltips and semantics labels that tests and TalkBack rely on are kept or remapped deliberately.
- **Dependencies**: none added; stays on Flutter 3.44 and `package:flutter/material.dart` (design D1).
- **Tests**: goldens regenerated; widget tests updated where a control moved (model picker, spoken replies, appearance controls).
