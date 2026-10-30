import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/expressive/expressive.dart';
import 'package:hermes_android/core/theme/hermes_theme.dart';

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: hermesTheme(Brightness.light),
      home: Scaffold(body: Center(child: child)),
    ),
  );
  await tester.pump();
}

void main() {
  group('ExpressiveShape', () {
    test('paths fit their rect and close', () {
      const rect = Rect.fromLTWH(0, 0, 100, 100);
      for (final shape in ExpressiveShape.marks) {
        final bounds = shape.path(rect).getBounds();
        expect(bounds.left, greaterThanOrEqualTo(-0.01), reason: '$shape');
        expect(bounds.right, lessThanOrEqualTo(100.01), reason: '$shape');
        expect(bounds.width, greaterThan(80), reason: '$shape');
      }
    });

    test('a project always gets the same mark', () {
      expect(
        MarkStyle.forKey('home-lab').shape,
        MarkStyle.forKey('home-lab').shape,
      );
      expect(
        MarkStyle.forKey('home-lab').tone,
        MarkStyle.forKey('home-lab').tone,
      );
      final shapes = {
        for (final key in ['a', 'garden', 'home-lab', 'notes', 'p-42', 'zz'])
          MarkStyle.forKey(key).shape,
      };
      expect(shapes.length, greaterThan(1));
    });
  });

  group('SpringCurve', () {
    test('starts at 0, lands at 1, and the spatial spring overshoots', () {
      const curve = SpringCurve(HermesSprings.spatialFast);
      expect(curve.transform(0), 0);
      expect(curve.transform(1), 1);
      final peak = [
        for (var t = 0.0; t <= 1; t += 0.01) curve.transform(t),
      ].reduce((a, b) => a > b ? a : b);
      expect(peak, greaterThan(1.0));
    });

    test('the effects spring never overshoots', () {
      const curve = SpringCurve(HermesSprings.effectsDefault);
      for (var t = 0.0; t <= 1; t += 0.01) {
        expect(curve.transform(t), lessThanOrEqualTo(1.0001));
      }
    });
  });

  testWidgets('segmented groups give rows 24dp outer and 4dp inner corners', (
    tester,
  ) async {
    final seen = <SegmentPosition?>[];
    await _pump(
      tester,
      SegmentedListGroup(
        children: [
          for (var i = 0; i < 3; i++)
            Builder(
              builder: (context) {
                seen.add(SegmentScope.maybeOf(context));
                return const SizedBox(height: 10);
              },
            ),
        ],
      ),
    );
    expect(seen, [
      SegmentPosition.first,
      SegmentPosition.middle,
      SegmentPosition.last,
    ]);
    expect(
      SegmentPosition.first.radius(),
      const BorderRadius.vertical(
        top: Radius.circular(24),
        bottom: Radius.circular(4),
      ),
    );
    expect(SegmentPosition.only.radius(), BorderRadius.circular(24));
  });

  testWidgets('connected button group selects one value', (tester) async {
    var selected = 'all';
    await _pump(
      tester,
      StatefulBuilder(
        builder: (context, setState) => ConnectedButtonGroup<String>(
          buttons: const [
            ConnectedButton(value: 'all', label: 'All'),
            ConnectedButton(value: 'recent', label: 'Recent'),
            ConnectedButton(value: 'archived', label: 'Archived'),
          ],
          selected: selected,
          onSelected: (value) => setState(() => selected = value),
        ),
      ),
    );
    final handle = tester.ensureSemantics();
    expect(
      tester.getSemantics(find.bySemanticsLabel('All')),
      isSemantics(
        isButton: true,
        isSelected: true,
        hasSelectedState: true,
        isInMutuallyExclusiveGroup: true,
        hasTapAction: true,
      ),
    );
    await tester.tap(find.text('Recent'));
    await tester.pumpAndSettle();
    expect(selected, 'recent');
    expect(tester.getSize(find.bySemanticsLabel('Recent')).height, 48);
    handle.dispose();
  });

  testWidgets('split button runs its primary action and menu items', (
    tester,
  ) async {
    final pressed = <String>[];
    await _pump(
      tester,
      SplitButton(
        label: 'Allow once',
        primaryKey: const Key('primary'),
        menuTooltip: 'More options',
        onPressed: () => pressed.add('once'),
        items: [
          SplitButtonItem(
            label: 'Always allow',
            onPressed: () => pressed.add('always'),
          ),
        ],
      ),
    );
    await tester.tap(find.byKey(const Key('primary')));
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Always allow'));
    await tester.pumpAndSettle();
    expect(pressed, ['once', 'always']);
  });

  testWidgets('determinate wavy progress does not animate', (tester) async {
    await _pump(
      tester,
      const SizedBox(width: 200, child: WavyProgressIndicator(value: 0.4)),
    );
    await tester.pumpAndSettle();
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('shape marks show the label initial', (tester) async {
    await _pump(
      tester,
      ShapeMark(style: MarkStyle.forKey('garden'), label: 'garden'),
    );
    expect(find.text('G'), findsOneWidget);
  });
}
