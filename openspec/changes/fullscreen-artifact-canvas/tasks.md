# Tasks

## 1. HtmlArtifactPreview zoom support

- [x] 1.1 Add `enableZoom` (default false) to `HtmlArtifactPreview`; when true call `controller.enableZoom(true)` and `AndroidWebViewController.setDisplayZoomControls(false)`. Verify: `flutter analyze`.

## 2. Card: maximize + sizing

- [x] 2.1 `MediaArtifactCard` preview header: add maximize `IconButton` (key `media-card-maximize`, tooltip `l10n.media_card_maximize`) that opens `Dialog.fullscreen` with `HtmlArtifactPreview(bytes, enableZoom: true)` (or the injected `previewBuilder` stub in tests, keyed `fullscreen-preview-stub`) plus a close button (tooltip `l10n.media_card_close_preview`). Black background like the image viewer. Verify with widget tests (button present when preview shown; tap → dialog with stub; back/close dismisses).
- [x] 2.2 In-bubble pane: `ConstrainedBox(minHeight: 240)` + `AspectRatio(16/11)` instead of bare 16/10. Verify with widget test (pane has min-height constraint) and analyze.

## 3. l10n

- [x] 3.1 Add `media_card_maximize` ("Maximize preview") and `media_card_close_preview` ("Close preview") to `app_en.arb`; run `flutter gen-l10n`. Verify analyze clean.

## 4. Verify and deliver

- [x] 4.1 `flutter analyze` clean; full `flutter test` green (exit code preserved); `openspec validate fullscreen-artifact-canvas` clean; no-hardcoded-colors + README window checks.
- [x] 4.2 Bump to v2.1.31-you.7 (pubspec + `test/release_identity_test.dart` + CHANGELOG + README bullet + `docs/releases/v2.1.31-you.7.md`); commit explicit paths on the feature branch.
- [ ] 4.3 Build signed split APKs, apksigner-verify all three against the keystore, Taildrop arm64 to ryders-z-fold8.
- [ ] 4.4 On-device QA: maximize the beads mockup, pinch-zoom/pan, close via back; in-bubble pane taller; sandbox still holds. Update bead.
