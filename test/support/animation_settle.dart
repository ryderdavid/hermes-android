import 'package:flutter_test/flutter_test.dart';

/// `pumpAndSettle` never returns while a busy chat mark morphs (an active
/// session in a list animates forever). This pumps until no frame is
/// scheduled — real settling when nothing animates — but caps the loop so a
/// perpetual morph cannot hang the test.
Future<void> settle(WidgetTester tester, {int maxFrames = 12}) async {
  for (var i = 0; i < maxFrames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
    if (!tester.binding.hasScheduledFrame) return;
  }
}
