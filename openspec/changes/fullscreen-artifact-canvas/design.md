# Design: Fullscreen artifact canvas

## Context

`inline-html-artifact-preview` (committed `f7ecd8d`, v2.1.31-you.6) renders HTML `MEDIA:` artifacts in a fixed 16:10 `AspectRatio` pane inside `MediaArtifactCard`. On a phone bubble (~320dp) that is ~200dp tall — cramped — and the header only offers share-to-browser. Canvas-style artifacts (boards, decks; Nacre's workspace canvas uses pan/pinch transform gestures with a zoom-% indicator) need a fullscreen viewport with zoom enabled.

## Goals

- Maximize button → fullscreen in-app sandboxed preview with pinch-zoom/pan.
- In-bubble pane at least 240dp tall.
- Sandbox identical in both modes (file access off, no JS bridge, navigation prevented, injected CSP).
- Widget-testable without a platform WebView (existing `previewBuilder` injection covers both panes).

## Non-goals

- Turning arbitrary HTML into an infinite canvas on the app side — the *artifact* implements canvas behavior (pan/zoom/place); the app provides the zoom-enabled viewport. The WebView handles native pinch-zoom/pan of the page.
- Multi-artifact canvas composition inside the app (placing several artifacts on one canvas) — that's artifact-side content, out of scope for the app shell.

## Decisions

### D1: Fullscreen via `Dialog.fullscreen`, reusing `HtmlArtifactPreview`
The maximize button opens `showDialog(Dialog.fullscreen(...))` containing a fresh `HtmlArtifactPreview` with `enableZoom: true`, over a black background like the existing image viewer (`media_artifact_card.dart` `_showImagePreview`). Fresh controller per open = clean state; bytes are already cached in `_bytes`. System back dismisses dialogs by default.

### D2: Zoom configuration
`HtmlArtifactPreview` gains `enableZoom` (default false). When true: `controller.enableZoom(true)` plus `AndroidWebViewController.setDisplayZoomControls(false)` so pinch-zoom works without on-screen +/- buttons. In-bubble mode keeps zoom off (fixed pane; content scrolls). The injected CSP is unchanged — zoom is a viewport transform, not a policy change.

### D3: In-bubble sizing
Replace `AspectRatio(16/10)` with `ConstrainedBox(minHeight: 240)` wrapping `AspectRatio(16/11)`: wider aspect plus a floor, so narrow bubbles get ≥240dp and wide bubbles scale up. Recorded as a constant in the card.

### D4: Header layout
Preview header row: "Live preview" label, spacer, maximize `IconButton` (`Icons.fullscreen_outlined`, key `media-card-maximize`, tooltip `media_card_maximize`), open-externally `IconButton` (existing key/tooltip). In the fullscreen dialog: top-right close `IconButton` (`Icons.close`, tooltip `media_card_close_preview`).

### D5: Tests
Widget tests with injected `previewBuilder` stub: maximize button present when preview shown; tapping it opens a dialog containing the stub (assert via key `fullscreen-preview-stub`); in-bubble pane has the min-height constraint; non-html/streaming/oversize still show no preview. `HtmlArtifactPreview.enableZoom` is a plain param — covered by analyze + on-device QA.

## Architecture

```
MediaArtifactCard (in-bubble)
  └─ header: [Live preview] [maximize] [open-externally]
  └─ ConstrainedBox(minHeight: 240) > AspectRatio(16/11) > previewBuilder(bytes)
       └─ tap maximize → Dialog.fullscreen
            └─ Stack[ HtmlArtifactPreview(bytes, enableZoom: true), close btn ]
```

## Security

Fullscreen uses the identical sandbox (D1/D2): no new capability is granted by maximizing. Zoom does not relax CSP or navigation policy.

## Open questions

- Whether the in-bubble pane should also allow vertical scroll of the page (default WebView behavior) — yes, unchanged; only zoom is gated.
