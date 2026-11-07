# Design: Inline HTML artifact preview in chat

## Context

Assistant messages carry gateway-host file references as `MEDIA:/path` tags. `lib/core/utils/media_tags.dart` splits them into prose + standalone refs; `lib/core/screens/chat_screen.dart:5371-5415` splices a `MediaArtifactCard` per standalone ref. Today the card (`lib/core/widgets/media_artifact_card.dart`) downloads bytes via the gateway `fs/download` (`RemoteFilesDataSource.download`), shows an inline thumbnail only for raster images (`_imageExts`, line 199), and otherwise offers download/share. `.html`/`.htm` are in the gateway delivery list (`kMediaDeliveryExts`, media_tags.dart:34) but render as a plain file card.

The desktop Hermes app renders the same artifacts as live sandboxed previews (artifact cards + `::preview{file=...}` directive; HTML runs in a `sandbox="allow-scripts"` iframe on an opaque origin). The roadmap scopes this for Android at `docs/ANDROID_DAILY_DRIVER_ROADMAP.md:420-425,618-619` ("artifact preview/version UI"; transcript-reconstructed artifact cards first, server index later).

## Goals

- HTML `MEDIA:` artifacts render live inline in chat on the phone.
- Sandbox parity with the desktop: scripts run, but no file access, no host bridge, no top-level navigation away, no same-origin access to app WebView storage.
- Zero behavior change for non-HTML artifacts and for streaming messages.
- Widget-testable without a real WebView (all gating/CSP logic in pure functions).

## Non-goals

- SVG/PDF/video inline rendering; artifact version history; `::preview{...}` directive parsing; server-side artifact index; multi-file artifact apps (relative sibling assets won't resolve under an opaque base URL — same limitation as the desktop srcdoc preview).

## Decisions

### D1: `webview_flutter` for the embedded preview
Add the official `webview_flutter` plugin (pin a version compatible with Flutter 3.44.0 and the project minSdk; verify at `flutter pub get`). Rationale: it is the maintained Android-WebView wrapper, already a category fit for an embedded read-only pane. The roadmap's rejection of a WebView-based app (PR #52673) was about making the whole app a WebView shell — irrelevant here; this is one card pane. Alternative considered: `flutter_inappwebview` (more features, heavier, less maintained); rejected for v1.

### D2: Load via `loadHtmlString` with opaque base URL
`WebViewController.loadHtmlString(html)` serves from `about:blank` — an opaque origin, the Android equivalent of the desktop's `sandbox` srcdoc iframe. Do NOT write a temp file and `loadUrl(file://...)`: with `fileAccessEnabled: false` that fails, and file access is a sandbox hole anyway. Single-file HTML artifacts (what the `sketch`/`claude-design` skills produce) work fully; relative sibling assets do not resolve — acceptable v1 limitation, surfaced in the preview header tooltip.

### D3: Sandbox configuration
- `JavaScriptMode.enabled` (artifacts are interactive by design).
- `WebViewSettings.fileAccessEnabled = false`, `allowFileAccessFromFileURLs = false`, `allowUniversalAccessFromFileURLs = false`.
- No `addJavascriptInterface` — no JS bridge to the app at all.
- `NavigationDelegate` returning `NavigationDecision.prevent` for every top-level navigation (artifact links open via the share/external affordance instead).
- Injected CSP meta as first element in `<head>` (fallback: prepend to document): `default-src 'none'; script-src 'unsafe-inline' https:; style-src 'unsafe-inline' https:; img-src data: blob: https:; font-src data: https:; connect-src https:; form-action 'none'; base-uri 'none'`. This allows Tailwind-CDN/Google-Fonts prototypes while blocking exfiltration channels and form posts. Injection is a pure string function (`injectArtifactCsp`) so it is unit-testable.

### D4: Gating and size cap as pure functions
`lib/core/utils/html_artifact_preview.dart` (pure, no Flutter WebView imports):
- `isPreviewableHtmlRef(MediaTagRef ref)` — extension in {html, htm}, case-insensitive.
- `kMaxPreviewBytes = 5 MiB`; `shouldMountPreview({required bool isFinal, required int? byteLength})`.
Unit-test these; the widget layer only wires them.

### D5: Mount only on final messages
`chat_screen.dart` already computes `mediaReferencesFinal`; pass it into `MediaArtifactCard` as `allowPreview`. While streaming, html refs show the plain card (the ref path can still grow; `splitMediaTags(isFinal: ...)` already guards the edge). When the message completes, the card re-renders with `allowPreview: true` and mounts the WebView from the already-downloaded bytes (no second download; `_ensureBytes()` caches).

### D6: Card layout
`MediaArtifactCard` gains an optional preview pane above the `ListTile`: fixed aspect (16:10) `ClipRRect` containing the WebView, a small header row (filename + "open externally" icon → existing share flow), a loading spinner while bytes download, and an error state (download failed or oversize → no pane, row only). `didUpdateWidget` path-change reset (media_artifact_card.dart:61-72) additionally disposes/reloads the preview.

## Architecture

```
chat_screen.dart (renderProse)
  └─ MediaArtifactCard(ref, filesClient, allowPreview: mediaReferencesFinal)
       ├─ _ensureBytes() ── RemoteFilesClient.download(ref.path) ──► gateway fs/download
       ├─ isPreviewableHtmlRef && allowPreview && size ≤ cap
       │     └─ HtmlArtifactPreview(bytes)
       │           └─ WebView(webview_flutter): loadHtmlString(injectArtifactCsp(utf8.decode(bytes)))
       └─ ListTile (filename, download/share) — unchanged
```

## Security considerations

- Artifact HTML is agent-generated and untrusted: the WebView sandbox (D3) is the only line of defense, matching desktop. No credentials flow into the page; there is no bridge to read them.
- WebView network requests go to the open internet (CDN scripts) — same as desktop artifact preview allowing specific CDNs; our CSP is slightly broader (`https:`) because the phone has no claudeusercontent origin to pin to. Recorded as an accepted risk; tightening to an explicit CDN allowlist is a follow-up.
- 5 MiB cap bounds memory/jank in `loadHtmlString`.
- `INTERNET` permission already present (AndroidManifest.xml:2).

## Testing

- Unit: `injectArtifactCsp` (injects into `<head>`, creates `<head>` when absent, escapes nothing since it is a fixed meta tag, idempotent), `isPreviewableHtmlRef`, `shouldMountPreview` (final/streaming/oversize matrix), ref-change teardown logic.
- Widget: `MediaArtifactCard` with a fake `RemoteFilesDataSource` — html+final+small → preview pane present; oversize → absent; non-html → absent; streaming → absent. WebView itself is not exercised in widget tests (no renderer); on-device QA covers it.
- Existing `test/media_tags_test.dart` must stay green (no parser changes).
- `flutter analyze` + `flutter test` green before merge (CLAUDE.md gates).

## Open questions

- Exact CSP allowlist breadth (D3 security note) — start broad, tighten later if a threat model demands.
- Preview aspect ratio (16:10 proposed) vs. fixed 1920×1080-scale like Claude Design's `<deck-stage>` — decide after on-device QA; keep as a constant.
- Whether the gateway should start emitting `::preview{file=...}` for pinned previews — future change; v1 keys off `MEDIA:` only.
