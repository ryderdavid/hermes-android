/// Pure gating and CSP logic for the inline HTML artifact preview.
///
/// Everything here is deliberately free of Flutter WebView imports so the
/// decision logic is unit-testable — a WebView cannot be exercised in
/// `flutter test` widget tests. See
/// `openspec/changes/inline-html-artifact-preview/design.md` (D3/D4).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'media_tags.dart';

/// Maximum artifact size that mounts an inline preview. Bounds
/// `loadHtmlString` memory and keeps chat scrolling smooth.
const int kMaxPreviewBytes = 5 * 1024 * 1024; // 5 MiB

/// Extensions that mount an inline sandboxed preview (case-insensitive;
/// `MediaTagRef.extension` is already lowercased).
const Set<String> kPreviewableExts = {'html', 'htm'};

/// True when [ref] names an HTML artifact that may render inline.
bool isPreviewableHtmlRef(MediaTagRef ref) =>
    kPreviewableExts.contains(ref.extension);

/// True when a preview pane may mount: the message must be final (a
/// streaming `MEDIA:` path can still grow) and the downloaded size must be
/// known and within [kMaxPreviewBytes].
bool shouldMountPreview({required bool isFinal, required int? byteLength}) {
  if (!isFinal) return false;
  if (byteLength == null) return false;
  return byteLength <= kMaxPreviewBytes;
}

/// The CSP injected into every previewed artifact document. Mirrors the
/// desktop's opaque-origin sandboxed iframe: scripts run, but the page can
/// only load https: subresources (Tailwind/jsDelivr/Google Fonts used by
/// generated prototypes), cannot post forms, and cannot phone anywhere
/// except https:. `default-src 'none'` blocks everything else (plugins,
/// WebRTC, camera/mic via permissions policy is separate).
const String kArtifactPreviewCsp =
    "default-src 'none'; "
    "script-src 'unsafe-inline' https:; "
    "style-src 'unsafe-inline' https:; "
    "img-src data: blob: https:; "
    "font-src data: https:; "
    "connect-src https:; "
    "form-action 'none'; "
    "base-uri 'none'; "
    "object-src 'none'";

final RegExp _cspMetaPattern = RegExp(
  r'''<meta\s+[^>]*http-equiv\s*=\s*["']?content-security-policy["']?[^>]*>''',
  caseSensitive: false,
);

String get _cspMetaTag =>
    '<meta http-equiv="Content-Security-Policy" content="$kArtifactPreviewCsp">';

/// Injects the preview CSP into [html], replacing any existing CSP meta tag
/// (idempotent). Inserted as the first child of `<head>` when present, after
/// `<html>` otherwise, or at the very start for fragment documents.
String injectArtifactCsp(String html) {
  final stripped = html.replaceAll(_cspMetaPattern, '');
  final headMatch = RegExp(
    r'<head[^>]*>',
    caseSensitive: false,
  ).firstMatch(stripped);
  if (headMatch != null) {
    final at = headMatch.end;
    return '${stripped.substring(0, at)}$_cspMetaTag${stripped.substring(at)}';
  }
  final htmlMatch = RegExp(
    r'<html[^>]*>',
    caseSensitive: false,
  ).firstMatch(stripped);
  if (htmlMatch != null) {
    final at = htmlMatch.end;
    return '${stripped.substring(0, at)}$_cspMetaTag${stripped.substring(at)}';
  }
  return '$_cspMetaTag$stripped';
}

/// Decodes artifact bytes as UTF-8 for `loadHtmlString`. Artifacts are
/// required to be UTF-8 (the gateway refuses undecodable publishes); the
/// replacement-character fallback keeps a bad file from throwing.
String decodeArtifactHtml(Uint8List bytes) =>
    utf8.decode(bytes, allowMalformed: true);
