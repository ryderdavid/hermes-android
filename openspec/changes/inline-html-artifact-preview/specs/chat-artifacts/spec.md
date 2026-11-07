# Spec Delta

## Purpose
How gateway-delivered `MEDIA:` artifacts are rendered in chat: file cards for all deliverable types, and a sandboxed live HTML preview pane for HTML artifacts, so agent-generated prototypes are reviewable inline on the phone.

## ADDED Requirements

### Requirement: HTML media refs render an inline sandboxed preview
When a standalone `MEDIA:` reference resolves to a path with extension `html` or `htm` (case-insensitive), the artifact card SHALL render the downloaded bytes in an embedded WebView above the existing file row. All other extensions SHALL keep the current card behavior (inline image for raster images, download/share otherwise).

#### Scenario: HTML artifact in a final message
- **WHEN** an assistant message contains a standalone `MEDIA:/path/to/mockup.html` and the message is final
- **THEN** the card shows a live rendered preview of the HTML plus the existing filename/download/share row

#### Scenario: Non-HTML artifact
- **WHEN** a standalone `MEDIA:` ref ends in `.png`, `.pdf`, `.svg`, etc.
- **THEN** the card renders exactly as before this change (image thumbnail or file row only)

### Requirement: The preview WebView runs with the sandbox settings
The preview WebView SHALL run with JavaScript enabled but file access disabled, SHALL NOT expose any `JavascriptInterface` to the page, SHALL block all top-level navigations via a `NavigationDelegate`, and SHALL load the HTML via `loadHtmlString` with an opaque base URL (no `file://` or host origin).

#### Scenario: Artifact tries to reach local files or navigate away
- **WHEN** the rendered HTML attempts `file://` access or a top-level navigation to an external URL
- **THEN** the attempt is blocked by the WebView settings and the NavigationDelegate respectively

### Requirement: A strict CSP is injected into the served document
The served document SHALL contain a CSP meta tag with `default-src 'none'`, `script-src 'unsafe-inline' https:`, `style-src 'unsafe-inline' https:`, `img-src`/`font-src` `data: blob: https:`, `connect-src https:`, `form-action 'none'`, and `base-uri 'none'`.

#### Scenario: Artifact tries to exfiltrate or post a form
- **WHEN** the rendered HTML issues a fetch to a non-https endpoint or submits a form
- **THEN** the injected CSP blocks it

### Requirement: Previews mount only for settled, size-capped files
The inline preview SHALL mount only when the containing message is final (not mid-stream) and the downloaded file is at most 5 MiB. Larger files or streaming messages SHALL show the plain card; when the message completes, the preview MAY appear without a re-download.

#### Scenario: Oversize artifact
- **WHEN** an HTML ref downloads to more than 5 MiB
- **THEN** the card shows the file row with download/share and no WebView

#### Scenario: Streaming message
- **WHEN** a `MEDIA:` html ref is still streaming (path may grow)
- **THEN** no WebView is mounted until the message is final

### Requirement: Preview lifecycle follows the ref
When the card's ref path changes (streaming growth, list recycling), any loaded preview SHALL be torn down and re-rendered from the new bytes; stale bytes SHALL NOT be displayed under a new filename.

#### Scenario: Recycled card
- **WHEN** a `MediaArtifactCard` is re-pointed at a different path
- **THEN** the previous preview content is cleared before the new bytes render

### Requirement: Download and share remain available
Every artifact card, HTML or not, SHALL keep the existing download/share action, and the preview pane SHALL offer an "open externally" affordance that routes through the existing share flow.

#### Scenario: User wants the raw file
- **WHEN** the user taps download/share on an HTML artifact with a preview showing
- **THEN** the file is shared exactly as before, with MIME `text/html`
