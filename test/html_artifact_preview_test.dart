import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/utils/html_artifact_preview.dart';
import 'package:hermes_android/core/utils/media_tags.dart';

void main() {
  group('isPreviewableHtmlRef', () {
    test('html and htm are previewable, case-insensitive', () {
      expect(
        isPreviewableHtmlRef(const MediaTagRef(path: '/a/b.html')),
        isTrue,
      );
      expect(isPreviewableHtmlRef(const MediaTagRef(path: '/a/b.htm')), isTrue);
      expect(
        isPreviewableHtmlRef(const MediaTagRef(path: '/a/b.HTML')),
        isTrue,
      );
    });

    test('other extensions are not previewable', () {
      for (final p in ['/a/b.png', '/a/b.svg', '/a/b.pdf', '/a/b.md']) {
        expect(isPreviewableHtmlRef(MediaTagRef(path: p)), isFalse, reason: p);
      }
    });
  });

  group('shouldMountPreview', () {
    test('requires a final message', () {
      expect(shouldMountPreview(isFinal: false, byteLength: 10), isFalse);
    });

    test('requires a known size', () {
      expect(shouldMountPreview(isFinal: true, byteLength: null), isFalse);
    });

    test('size cap is enforced inclusively', () {
      expect(
        shouldMountPreview(isFinal: true, byteLength: kMaxPreviewBytes),
        isTrue,
      );
      expect(
        shouldMountPreview(isFinal: true, byteLength: kMaxPreviewBytes + 1),
        isFalse,
      );
    });
  });

  group('injectArtifactCsp', () {
    test('injects into an existing <head> as its first child', () {
      final out = injectArtifactCsp(
        '<html><head><title>t</title></head><body>x</body></html>',
      );
      expect(
        out.indexOf('http-equiv="Content-Security-Policy"'),
        lessThan(out.indexOf('<title>')),
      );
      expect(out, contains(kArtifactPreviewCsp));
    });

    test('falls back to after <html> when there is no <head>', () {
      final out = injectArtifactCsp('<html><body>x</body></html>');
      expect(
        out.indexOf('<html>'),
        lessThan(out.indexOf('Content-Security-Policy')),
      );
    });

    test('prepends to a fragment document', () {
      final out = injectArtifactCsp('<p>hi</p>');
      expect(
        out.startsWith('<meta http-equiv="Content-Security-Policy"'),
        isTrue,
      );
    });

    test('is idempotent and replaces an existing CSP meta', () {
      const doc =
          '<html><head><meta http-equiv="Content-Security-Policy" content="default-src \'self\'"><title>t</title></head></html>';
      final once = injectArtifactCsp(doc);
      final twice = injectArtifactCsp(once);
      expect(twice, equals(once));
      expect(
        RegExp(
          'http-equiv="Content-Security-Policy"',
          caseSensitive: false,
        ).allMatches(twice).length,
        1,
      );
      expect(twice, isNot(contains("default-src 'self'")));
    });

    test('CSP policy matches the designed sandbox', () {
      expect(kArtifactPreviewCsp, contains("default-src 'none'"));
      expect(
        kArtifactPreviewCsp,
        contains("script-src 'unsafe-inline' https:"),
      );
      expect(kArtifactPreviewCsp, contains("connect-src https:"));
      expect(kArtifactPreviewCsp, contains("form-action 'none'"));
      expect(kArtifactPreviewCsp, contains("object-src 'none'"));
    });
  });

  group('decodeArtifactHtml', () {
    test('decodes utf-8 and tolerates malformed bytes', () {
      expect(
        decodeArtifactHtml(Uint8List.fromList(utf8.encode('<p>é</p>'))),
        '<p>é</p>',
      );
      expect(
        decodeArtifactHtml(Uint8List.fromList([0x3c, 0xff, 0x3e])),
        isNotEmpty,
      );
    });
  });
}
