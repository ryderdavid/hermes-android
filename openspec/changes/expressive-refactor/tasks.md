# Tasks

## 1. Expressive kit

- [x] 1.1 `ExpressiveShape` (cookie, clover, sunny, burst, flower, soft), `ExpressiveShapeBorder`, `ShapeMark` and a stable project→shape/role mapping; unit and golden tests.
- [x] 1.2 `HermesSprings` tokens and `SpringCurve`; unit test that the curve starts at 0, ends at 1 and overshoots for the expressive spatial springs.
- [x] 1.3 `ExpressiveLoadingIndicator` and `WavyProgressIndicator`; golden test.
- [x] 1.4 `SegmentedListGroup` and `SegmentedTile`; `SettingsGroup` delegates to it; golden test of 1, 2 and 3-row groups.
- [x] 1.5 `ConnectedButtonGroup` (single select, spring corner morph) and `SplitButton` (primary plus menu); widget tests for selection and menu.

## 2. Theme

- [x] 2.1 Emphasized type styles and `HermesTypography.emphasized`; corner tokens; `LargeHeader` widget.
- [x] 2.2 64dp NavigationBar, FAB sizes and shapes, sheet and dialog shapes, list tile defaults; shell golden regenerated.

## 3. Home and panes

- [x] 3.1 Workspace destinations use `LargeHeader`; Home leads with a `SearchBar` that opens chat search.
- [x] 3.2 Home pane: "Needs you" carousel cards (approval, running with wavy progress) and recent chats as a segmented list with shape marks.
- [x] 3.3 Projects, Activity and More panes adopt segmented lists and shape marks.

## 4. Chats

- [ ] 4.1 Chats list: large header, connected button group filters, day groups as segmented lists with shape marks and status labels; keep search, actions menu and paging.

## 5. Chat

- [ ] 5.1 App bar: shape avatar, title, model subtitle that opens the model picker; spoken replies as a checkable overflow item.
- [ ] 5.2 Assistant replies without bubbles; user bubble `primaryContainer` with 24/24/6/24 corners; compact density respected.
- [ ] 5.3 Tool-activity card and turn status restyled; shape loading indicator while working.
- [ ] 5.4 Composer: attach circle outside, pill with dictation, Send/Stop spring morph; chip row removed; tests updated.

## 6. Sheets

- [ ] 6.1 Approval presented as a modal bottom sheet with Deny and a split Approve button; existing approval tests pass with the same results.

## 7. Settings

- [ ] 7.1 Settings: large header, connection card, segmented groups with tonal icons; device-local rows survive dashboard failure.
- [ ] 7.2 Color & theme page: connected theme group, shape swatches, pure black, text size and chat density; widget tests for theme, color and persistence.

## 8. Verify and deliver

- [ ] 8.1 Full suite, analyze, colour lint; goldens regenerated and reviewed; accessibility guideline tests cover the new screens.
- [ ] 8.2 Version 2.1.30-you.3; signed split release APKs; GitHub release on the fork; APK sent to the phone over Tailscale; smoke test on the tablet.
