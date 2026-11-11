import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/theme/hermes_theme.dart';
import 'package:hermes_android/core/widgets/turn_fold.dart';

import 'support/l10n_test_utils.dart';

Future<void> _pump(WidgetTester tester, Widget line) async {
  await tester.pumpWidget(
    testAppWithL10n(Scaffold(body: ListView(children: [line]))),
  );
  await tester.pump();
}

void main() {
  testWidgets('states how long the turn worked', (tester) async {
    await _pump(
      tester,
      const TurnFoldLine(
        duration: Duration(minutes: 2, seconds: 24),
        stepCount: 6,
      ),
    );
    expect(find.text('Worked for 2m 24s'), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsNothing);
    expect(
      tester.getSize(find.byType(TurnFoldLine)).height,
      TurnFoldLine.minHeight,
    );
  });

  testWidgets('formats seconds, minutes and hours', (tester) async {
    for (final (duration, label) in [
      (const Duration(milliseconds: 300), 'Worked for 1s'),
      (const Duration(seconds: 45), 'Worked for 45s'),
      (const Duration(minutes: 1), 'Worked for 1m 0s'),
      (const Duration(hours: 1, minutes: 5, seconds: 30), 'Worked for 1h 5m'),
    ]) {
      await _pump(tester, TurnFoldLine(duration: duration, stepCount: 1));
      expect(find.text(label), findsOneWidget, reason: label);
    }
  });

  testWidgets('states the step count when the time is unknown', (tester) async {
    await _pump(tester, const TurnFoldLine(stepCount: 6));
    expect(find.text('Worked through 6 steps'), findsOneWidget);

    await _pump(tester, const TurnFoldLine(stepCount: 1));
    expect(find.text('Worked through 1 step'), findsOneWidget);
  });

  testWidgets('marks a turn in which something failed, in the error colour', (
    tester,
  ) async {
    await _pump(
      tester,
      const TurnFoldLine(
        duration: Duration(seconds: 30),
        stepCount: 4,
        failureCount: 2,
      ),
    );
    final danger = HermesTokens.of(
      tester.element(find.byType(TurnFoldLine)),
    ).danger;
    expect(tester.widget<Icon>(find.byIcon(Icons.error_outline)).color, danger);
    expect(tester.widget<Text>(find.text('2 failed')).style!.color, danger);
  });

  testWidgets('the chevron shows whether the turn is unfolded', (tester) async {
    await _pump(tester, const TurnFoldLine(stepCount: 2, unfolded: true));
    expect(find.byIcon(Icons.expand_less), findsOneWidget);
    expect(find.byIcon(Icons.chevron_right), findsNothing);
  });

  testWidgets('tapping it calls onTap', (tester) async {
    var taps = 0;
    await _pump(tester, TurnFoldLine(stepCount: 2, onTap: () => taps++));
    await tester.tap(find.byType(TurnFoldLine));
    expect(taps, 1);
  });

  testWidgets('announces the line, the failure and what a tap does', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(
      tester,
      TurnFoldLine(
        duration: const Duration(minutes: 2, seconds: 24),
        stepCount: 6,
        failureCount: 1,
        onTap: () {},
      ),
    );
    expect(
      tester.getSemantics(find.byType(TurnFoldLine)),
      matchesSemantics(
        label: 'Worked for 2m 24s, 1 failed',
        isButton: true,
        hasTapAction: true,
        onTapHint: 'Show steps',
      ),
    );

    await _pump(
      tester,
      TurnFoldLine(stepCount: 6, unfolded: true, onTap: () {}),
    );
    expect(
      tester.getSemantics(find.byType(TurnFoldLine)),
      matchesSemantics(
        label: 'Worked through 6 steps',
        isButton: true,
        hasTapAction: true,
        onTapHint: 'Hide steps',
      ),
    );
    handle.dispose();
  });
}
