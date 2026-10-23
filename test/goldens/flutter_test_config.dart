import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden tests render real Roboto, Material Icons and Cinzel so the images
/// are reviewable, and compare with a small tolerance so anti-aliasing
/// differences between macOS and Linux runners don't fail the build.
///
/// Regenerate with `flutter test --update-goldens test/goldens`.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  TestWidgetsFlutterBinding.ensureInitialized();
  await _loadFonts();
  if (goldenFileComparator is LocalFileComparator) {
    goldenFileComparator = _TolerantComparator(
      (goldenFileComparator as LocalFileComparator).basedir.resolve('x.dart'),
    );
  }
  await testMain();
}

const double _tolerance = 0.015;

class _TolerantComparator extends LocalFileComparator {
  _TolerantComparator(super.testFile);

  @override
  Future<bool> compare(Uint8List imageBytes, Uri golden) async {
    final result = await GoldenFileComparator.compareLists(
      imageBytes,
      await getGoldenBytes(golden),
    );
    if (result.passed || result.diffPercent <= _tolerance) {
      result.dispose();
      return true;
    }
    final error = await generateFailureOutput(result, golden, basedir);
    result.dispose();
    throw FlutterError(error);
  }
}

Future<void> _loadFonts() async {
  final flutterRoot = Platform.environment['FLUTTER_ROOT'];
  if (flutterRoot != null) {
    final dir = '$flutterRoot/bin/cache/artifacts/material_fonts';
    await _load('Roboto', [
      '$dir/Roboto-Regular.ttf',
      '$dir/Roboto-Medium.ttf',
      '$dir/Roboto-Bold.ttf',
    ]);
    await _load('MaterialIcons', ['$dir/MaterialIcons-Regular.otf']);
    // Code blocks ask for the platform `monospace` family, which tests do
    // not have; Roboto keeps them readable in the images.
    await _load('monospace', ['$dir/Roboto-Regular.ttf']);
  }
  await _load('Cinzel', ['assets/fonts/Cinzel-Variable.ttf']);
}

Future<void> _load(String family, List<String> paths) async {
  final loader = FontLoader(family);
  var any = false;
  for (final path in paths) {
    final file = File(path);
    if (!file.existsSync()) continue;
    final bytes = file.readAsBytesSync();
    loader.addFont(Future.value(ByteData.view(bytes.buffer)));
    any = true;
  }
  if (any) await loader.load();
}
