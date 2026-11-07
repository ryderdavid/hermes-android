# Tasks

## 1. Dependency and pure helpers

- [x] 1.1 Add `webview_flutter` to `pubspec.yaml` (pin a version compatible with Flutter 3.44.0 / current minSdk), run `flutter pub get`. Verify: pub get succeeds and `flutter analyze` stays clean.
- [x] 1.2 New `lib/core/utils/html_artifact_preview.dart` with pure functions: `isPreviewableHtmlRef(MediaTagRef)`, `kMaxPreviewBytes` (5 MiB), `shouldMountPreview({isFinal, byteLength})`, and `injectArtifactCsp(String html)`. Verify with unit tests in `test/html_artifact_preview_test.dart` (extension matrix incl. case-insensitivity; final/streaming/oversize matrix; CSP injected once, into `<head>` when present, document start otherwise; CSP string matches the design D3 policy).

## 2. Preview widget

- [x] 2.1 New `lib/core/widgets/html_artifact_preview.dart`: `HtmlArtifactPreview(Uint8List bytes)` building a `WebView` with the D3 sandbox settings (JS on, file access off, no JS interface, NavigationDelegate preventing all top-level navigation, opaque `loadHtmlString` base URL), loading `injectArtifactCsp(utf8.decode(bytes))`. Fixed-aspect container + header row with "open externally" wired to the existing share flow + loading/error states. Verify: `flutter analyze`; widget test that the widget builds with small html bytes (WebView platform view is not exercised in tests — assert the surrounding scaffold).
- [x] 2.2 `MediaArtifactCard`: accept `allowPreview` (default false); when `allowPreview && isPreviewableHtmlRef(ref)` and downloaded bytes ≤ `kMaxPreviewBytes`, show the preview pane above the ListTile; keep the existing filename/download/share row untouched. Extend the `didUpdateWidget` path-change reset to clear preview state. Verify with widget tests using a fake `RemoteFilesDataSource` (html+final+small → pane; oversize → no pane; non-html → no pane; streaming → no pane; path change → state reset).

## 3. Chat wiring

- [x] 3.1 `chat_screen.dart`: pass `allowPreview: mediaReferencesFinal` into each `MediaArtifactCard` in `renderProse` (and the inline-link path unchanged). Verify: streaming html refs render as plain cards until final; `flutter analyze`.
- [x] 3.2 l10n: add keys to `app_en.arb` (`media_card_preview`, `media_card_open_externally`); other locales fall back. Verify: `flutter gen-l10n` + `flutter analyze` clean.

## 4. Verify and deliver

- [x] 4.1 Run `flutter analyze` and full `flutter test` green, including existing `test/media_tags_test.dart`. Verify with both outputs.
- [x] 4.2 `openspec validate --change inline-html-artifact-preview` clean; review artifacts with the user.
- [ ] 4.3 On-device QA: drive a gateway session that emits a `MEDIA:` html artifact (e.g. via the `sketch`/`claude-design` flow); confirm the card renders inline, sandbox holds (no file access, no navigation), Tailwind-CDN prototype loads, download/share still works, and a >5 MiB html falls back to the plain card. Verify on the Fold 8.
- [x] 4.4 Commit on `feat/inline-html-artifact-preview` at logical checkpoints; release as the next `-you.N` build with signed split APKs per the usual pipeline.

## Workflow follow-up

- After merge: `/openspec-archive-change` + `/openspec-sync-specs` so `chat-artifacts` lands in `openspec/specs/`.
- Future phases (not this change): SVG/PDF preview, artifact version history, `::preview{...}` directive, server-authoritative artifact index (roadmap 618-619).
