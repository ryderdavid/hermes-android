# Design: Material 3 Expressive front-end refactor

## Context

Visual target: the "Hermes Expressive" canvas (system sheet plus Home, Chats, Chat, Approval, Settings and Color & theme screens). Base: `feat/backup-full-coverage` (v2.1.30-you.2 plus the send-button accessibility fix and full backup coverage). The app is Flutter 3.44 on `package:flutter/material.dart`; the theme module (`lib/core/theme/hermes_theme.dart`) already owns color, component themes and tokens, and screens read roles rather than hex.

## Goals / Non-Goals

**Goals:** Pixel-native Material 3 Expressive look on every primary screen; one reusable kit instead of per-screen one-offs; behaviour, data flow and accessibility labels unchanged unless a control deliberately moves.

**Non-Goals:** no `material_ui`/Flutter 3.47 migration; no new navigation destinations or routes beyond the Color & theme page; no networking, turn, recovery or storage changes; no bundled font download.

## Decisions

### D1. Build an in-repo expressive kit on Flutter 3.44
Material 3 Expressive components ship only in the standalone `material_ui` package for Flutter 3.47+, and community packages require it too. Upstream CI pins Flutter 3.44 and every screen imports `package:flutter/material.dart`, so migrating would touch every file and break rebases. The kit implements only what the design uses, on public Flutter APIs. *Revisit:* `hmy-xfw` (material_ui migration) can later swap kit widgets for official ones behind the same names.

### D2. Shapes as polar curves
Expressive shapes (cookie 9, clover 4, sunny 8, burst 12, flower 6, soft 4) are drawn as `r(θ) = (1 + a·cos nθ)/(1 + a)` paths. `ExpressiveShape` holds `n` and `a`; `ExpressiveShapeBorder` makes them usable as any `ShapeBorder`; `ShapeMark` paints a glyph or icon in one. Projects get a stable shape and container role from a hash of their id, so a project looks the same everywhere.

### D3. Springs
`HermesSprings` holds the Expressive scheme tokens (spatial fast 0.6/800, default 0.8/380, slow 0.8/200; effects 1.0/3800, 1600, 800). `SpringCurve` adapts a `SpringSimulation` to a `Curve` so implicit animations (`AnimatedContainer`, `AnimatedSwitcher`) move on springs.

### D4. Segmented lists replace cards
`SegmentedListGroup` lays out rows as tiles with 24dp outer and 4dp inner corners separated by 2dp, on `surfaceContainerLow` (default) or `surfaceContainer`. `SettingsGroup` becomes a thin wrapper so Settings code stays small. `SegmentedTile` is the list row: leading tonal icon circle or shape mark, title, supporting text, trailing widget, `onTap`.

### D5. Emphasized typography without a bundled font
Pixel's system face is not available to Flutter by default, so the platform Roboto stays. Emphasized styles come from weight: headline and display at 600–700, title-large 500–600, label emphasized 700. `HermesTypography.emphasized(TextStyle)` applies it.

### D6. Navigation and headers
NavigationBar height 64 with the label shown, secondary-container indicator. Destination panes use a `LargeHeader` (36sp emphasized title plus optional subtitle) instead of a centred small app bar; Home leads with the M3 `SearchBar`, which opens the existing chat search.

### D7. Chat
Assistant messages render as full-width markdown with no bubble; user messages keep a `primaryContainer` bubble with a 6dp corner at the sender side. Compact density keeps its tighter gaps. The app bar shows a shape avatar, the title, and the model as a tappable subtitle that opens the existing model picker (`_showModelSelector`). Spoken replies move to the chat overflow menu as a checkable item. While a turn runs, the turn status uses `ExpressiveLoadingIndicator`.

### D8. Composer
Attach becomes a 48dp tonal circle outside the field; the field keeps dictation inside; Send/Stop is one 48dp filled button whose corner radius springs from 24 (Send) to 14 (Stop). The model/spoken-reply chip row is removed (D7 relocates both). Existing keys, tooltips and the merged semantics stay.

### D9. Approval as a sheet
`showGatewayApprovalDialog` keeps its signature and result type but presents a modal bottom sheet: shape mark and "Approval needed", headline, description, command in a code block, then Deny and a split button whose primary is the narrowest allow choice and whose menu lists the rest (session/always) when the gateway offers them.

### D10. Settings and Color & theme
Top-level Settings: large header, connection card (shape mark, label, host, status), then segmented groups with tonal icons: model and sources; Color & theme (pushes the new page), text and density, notifications, voice; backup, about. The Color & theme page holds the theme connected button group, shape swatches (wallpaper, Hermes gold, presets), pure black, and text size and chat density. Device-local controls stay reachable when the dashboard fails.

### D11. Tests
Goldens are regenerated after each group and reviewed by eye. Widget tests that drive a moved control are updated to the new path; accessibility guideline tests run on the new screens.

## Risks / Trade-offs

- [Kit diverges from official M3E] → names and token values follow the spec; `hmy-xfw` swaps implementations later.
- [Upstream churn in chat_screen.dart] → chat changes stay in the bubble builder, app bar and menu; composer lives in its own file.
- [Moved controls surprise existing users] → model and spoken replies stay one tap away with the same labels.
