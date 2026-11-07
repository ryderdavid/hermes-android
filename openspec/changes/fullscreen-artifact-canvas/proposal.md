# Proposal: Fullscreen artifact canvas — maximize, pinch-zoom, less cramped preview

## Why

The inline HTML preview from `inline-html-artifact-preview` renders artifacts in a fixed 16:10 pane inside the chat bubble. On a phone bubble (~320dp wide) that is ~200dp tall — too cramped to read or interact with, and the only "expand" affordance is share-to-external-browser, which leaves the app. Canvas-style artifacts (boards, decks, mockups like Nacre's workspace) need a real maximize gesture into a fullscreen surface where pan/pinch-zoom work, i.e. an infinite-canvas viewport.

## What Changes

- The preview header gains a **maximize** button (fullscreen icon) next to "open in browser". Tapping it opens a **fullscreen sandboxed preview** (same `HtmlArtifactPreview` widget, same CSP/sandbox) with WebView **zoom enabled** (pinch-zoom, no on-screen zoom buttons), so canvas artifacts can be panned/zoomed inside the app.
- The in-bubble preview pane gets a larger footprint (wider aspect + minimum height) so content is readable without maximizing.
- Sandbox posture is unchanged in fullscreen: file access off, no JS bridge, navigation blocked, injected CSP. Fullscreen is dismissed with a close button / system back.
- Non-HTML artifacts unchanged.

## Capabilities

### Modified Capabilities
- `chat-artifacts`: the inline HTML preview gains a fullscreen mode with zoom; the in-bubble pane minimum size increases.

## Impact

- `lib/core/widgets/media_artifact_card.dart`: header maximize button + fullscreen dialog; pane sizing.
- `lib/core/widgets/html_artifact_preview.dart`: `enableZoom` parameter wired to `WebViewController.enableZoom` (+ `setDisplayZoomControls(false)`).
- `lib/l10n/app_en.arb`: `media_card_maximize` / `media_card_close_preview` keys; gen-l10n.
- Tests: widget tests for the maximize button + dialog (injected preview builder), full suite + analyze green.
- Release as next `-you.N` (v2.1.31-you.7) with signed split APKs.
