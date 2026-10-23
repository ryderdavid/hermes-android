import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Runs tools/check_no_hardcoded_colors.sh, which CI also runs, so a
/// hardcoded color fails `flutter test` locally too.
ProcessResult _lint([String? root]) =>
    Process.runSync('bash', ['tools/check_no_hardcoded_colors.sh', ?root]);

void main() {
  test('app code takes every color from the scheme', () {
    final result = _lint();
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  });

  test('the lint fails on a planted hardcoded color', () {
    final dir = Directory.systemTemp.createTempSync('color_lint');
    addTearDown(() => dir.deleteSync(recursive: true));
    File('${dir.path}/core/widgets/bad.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        'final a = Colors.red;\nfinal b = Colors.transparent;\n',
      );
    File('${dir.path}/core/theme/ok.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('const seed = Color(0xFF4285F4);\n');
    File(
      '${dir.path}/core/widgets/viewer.dart',
    ).writeAsStringSync('final bg = Colors.black; // allow-hardcoded-color\n');

    final result = _lint(dir.path);

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('bad.dart:1'));
    expect(result.stderr, isNot(contains('bad.dart:2')));
    expect(result.stderr, isNot(contains('ok.dart')));
    expect(result.stderr, isNot(contains('viewer.dart')));
  });
}
