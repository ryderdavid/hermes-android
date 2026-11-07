# Proposal: Inline HTML artifact preview in chat (sandboxed WebView cards)

## Why

Today a `MEDIA:`-delivered `.html`/`.htm` file renders as a plain file card: tap → download → system share sheet → external browser (`lib/core/widgets/media_artifact_card.dart`). On the Hermes desktop app the same artifact instead becomes a live, sandboxed preview card you can iterate on in place. Phone-driven sessions (this app → gateway → agent) are exactly where prototyping happens — the agent writes a self-contained HTML mockup on the host, the gateway delivers the bytes, and the phone should show it rendered inline in the chat, not buried behind a share sheet. This closes the gap called out in `docs/ANDROID_DAILY_DRIVER_ROADMAP.md` ("Artifacts — generated HTML, SVG, code, documents, and versions"; "artifact preview/version UI").

## What Changes

- `MEDIA:` refs with an `html`/`htm` extension render an **inline live preview** inside the existing `MediaArtifactCard`: a sandboxed Android WebView showing the artifact HTML, with the existing download/share row retained below it.
- The WebView is locked down to match the desktop's opaque-origin sandboxed-iframe semantics: JavaScript enabled, file access disabled, no host-app JS bridge, top-level navigation blocked, and a strict injected CSP meta tag (inline scripts + https: CDN resources only, matching what generated prototypes use — Tailwind/jsDelivr/Google Fonts).
- Previews render only for **final** (non-streaming) messages and only for files under a size cap; oversize or non-HTML refs keep today's card behavior unchanged.
- Non-HTML artifacts (images, SVG, PDF, …) are unchanged in v1. Version history, the desktop `::preview{file=...}` directive, and a server-authoritative artifact index remain out of scope (roadmap, later phase).

## Capabilities

### New Capabilities
- `chat-artifacts`: rendering of gateway-delivered `MEDIA:` artifacts as cards in chat, including sandboxed inline HTML preview for HTML artifacts.

### Modified Capabilities
- None (no existing spec covers media/artifact rendering; `chat-artifacts` is introduced by this change).

## Impact

- `pubspec.yaml`: add `webview_flutter` (pin a version compatible with Flutter 3.44.0 / current minSdk).
- `lib/core/widgets/media_artifact_card.dart`: add an `HtmlArtifactPreview` pane for html/htm refs; keep download/share.
- New `lib/core/widgets/html_artifact_preview.dart` (WebView config, CSP injection, gating, size cap, loading/error states) + pure helpers in `lib/core/utils/` for testability.
- `lib/core/screens/chat_screen.dart`: pass the final/streaming flag through so previews mount only on settled messages.
- l10n keys (en; other locales fall back). Tests for gating/CSP logic and card fallback; `flutter analyze` + `flutter test` green.
- No gateway or wire-format changes; no changes to `MEDIA:` parsing.
