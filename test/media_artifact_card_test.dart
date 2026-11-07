import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/services/remote_files_client.dart';
import 'package:hermes_android/core/utils/html_artifact_preview.dart';
import 'package:hermes_android/core/utils/media_tags.dart';
import 'package:hermes_android/core/widgets/media_artifact_card.dart';
import 'package:hermes_android/l10n/app_localizations.dart';

class FakeMediaFiles implements RemoteFilesDataSource {
  final Map<String, List<int>> files;
  final List<String> requested = [];
  FakeMediaFiles(this.files);

  @override
  Future<RemoteDirectory> defaultDirectory() async =>
      throw UnimplementedError();

  @override
  Future<List<RemoteFileEntry>> listDirectory(String path) async =>
      throw UnimplementedError();

  @override
  Future<RemoteTextPreview> readText(String path) async =>
      throw UnimplementedError();

  @override
  Future<RemoteFileDownload> download(String path) async {
    requested.add(path);
    final bytes = files[path];
    if (bytes == null) throw Exception('no such file: $path');
    return RemoteFileDownload(filename: path.split('/').last, bytes: bytes);
  }
}

Future<void> pumpCard(
  WidgetTester tester, {
  required MediaTagRef ref,
  required FakeMediaFiles files,
  bool allowPreview = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: 320, // chat-bubble width, not the full test surface
            child: MediaArtifactCard(
              ref: ref,
              filesClient: () => files,
              allowPreview: allowPreview,
              // A platform WebView cannot run in widget tests; stand in a stub.
              previewBuilder: (bytes) => Container(
                key: const Key('preview-stub'),
                color: Colors.transparent, // test-only stub, not shipped UI
                child: Text('${bytes.length}'),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  const htmlRef = MediaTagRef(path: '/out/mockup.html');
  final smallHtml = '<html><head></head><body>hi</body></html>'.codeUnits;

  testWidgets('html ref on a final message mounts the preview', (tester) async {
    final files = FakeMediaFiles({'/out/mockup.html': smallHtml});
    await pumpCard(tester, ref: htmlRef, files: files, allowPreview: true);
    expect(find.byKey(const Key('preview-stub')), findsOneWidget);
    expect(
      find.byKey(const Key('media-card-/out/mockup.html')),
      findsOneWidget,
    );
    expect(files.requested, ['/out/mockup.html']);
  });

  testWidgets(
    'streaming message (allowPreview=false) does not preview or download',
    (tester) async {
      final files = FakeMediaFiles({'/out/mockup.html': smallHtml});
      await pumpCard(tester, ref: htmlRef, files: files, allowPreview: false);
      expect(find.byKey(const Key('preview-stub')), findsNothing);
      expect(files.requested, isEmpty);
    },
  );

  testWidgets('oversize html downloads but does not mount a preview', (
    tester,
  ) async {
    final files = FakeMediaFiles({
      '/out/big.html': List<int>.filled(kMaxPreviewBytes + 1, 0x61),
    });
    await pumpCard(
      tester,
      ref: const MediaTagRef(path: '/out/big.html'),
      files: files,
      allowPreview: true,
    );
    expect(files.requested, ['/out/big.html']);
    expect(find.byKey(const Key('preview-stub')), findsNothing);
  });

  testWidgets('non-html refs never mount a preview', (tester) async {
    final files = FakeMediaFiles({
      '/out/chart.png': [1, 2, 3],
      '/out/doc.pdf': [1, 2, 3],
    });
    await pumpCard(
      tester,
      ref: const MediaTagRef(path: '/out/chart.png'),
      files: files,
      allowPreview: true,
    );
    expect(find.byKey(const Key('preview-stub')), findsNothing);
  });

  testWidgets(
    're-pointing the card at a new path re-downloads and re-keys the preview',
    (tester) async {
      final files = FakeMediaFiles({
        '/out/a.html': smallHtml,
        '/out/b.html': smallHtml,
      });
      await pumpCard(
        tester,
        ref: const MediaTagRef(path: '/out/a.html'),
        files: files,
        allowPreview: true,
      );
      expect(find.byKey(const Key('preview-stub')), findsOneWidget);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320, // chat-bubble width, not the full test surface
                child: MediaArtifactCard(
                  ref: const MediaTagRef(path: '/out/b.html'),
                  filesClient: () => files,
                  allowPreview: true,
                  previewBuilder: (bytes) => Container(
                    key: const Key('preview-stub'),
                    color: Colors.transparent, // test-only stub, not shipped UI
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(files.requested, ['/out/a.html', '/out/b.html']);
      expect(find.byKey(const Key('preview-stub')), findsOneWidget);
    },
  );
}
