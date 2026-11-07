# Spec Delta — chat-artifacts (fullscreen canvas additions)

## ADDED Requirements

### Requirement: In-bubble preview pane has a minimum height (supersedes the 16:10-only sizing)
When a standalone `MEDIA:` reference resolves to a path with extension `html` or `htm` (case-insensitive), the artifact card SHALL render the downloaded bytes in an embedded WebView above the existing file row. The in-bubble pane SHALL be at least 240 logical pixels tall (aspect 16:11 with a minimum-height floor), up from the previous 16:10-only sizing. All other extensions SHALL keep the current card behavior.

#### Scenario: HTML artifact in a final message
- **WHEN** an assistant message contains a standalone `MEDIA:/path/to/mockup.html` and the message is final
- **THEN** the card shows a live preview pane at least 240dp tall plus the existing filename/download/share row

### Requirement: The preview offers a fullscreen canvas mode
The preview header SHALL offer a maximize action that opens the same artifact in a fullscreen in-app surface (dialog/route) using the same sandboxed WebView configuration, with WebView zoom enabled (`enableZoom(true)`, no on-screen zoom controls) so pan/pinch gestures operate on canvas-type content. The fullscreen surface SHALL have a close affordance and SHALL be dismissible with system back.

#### Scenario: User maximizes a board artifact
- **WHEN** the user taps the maximize icon on an HTML artifact card
- **THEN** a fullscreen sandboxed preview opens; pinch-zoom changes the page scale; tapping close or system back dismisses it and returns to the chat with scroll position intact

#### Scenario: Sandbox still holds in fullscreen
- **WHEN** the fullscreen preview is open and the artifact attempts `file://` access, a top-level navigation, or a non-https fetch
- **THEN** the attempt is blocked exactly as in the in-bubble preview (file access off, NavigationDelegate, injected CSP)

## ADDED Requirements

### Requirement: Preview controls are labeled for accessibility
The preview header's maximize and open-externally icon buttons SHALL carry tooltips from the l10n catalog (`media_card_maximize`, `media_card_open_externally`) and the fullscreen surface SHALL carry a close tooltip (`media_card_close_preview`).

#### Scenario: TalkBack user explores the card
- **WHEN** an assistive service reads the preview header of an HTML artifact card
- **THEN** it announces "Maximize preview" and "Open in browser", and in fullscreen "Close preview"
