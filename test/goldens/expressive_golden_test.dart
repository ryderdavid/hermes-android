import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/expressive/expressive.dart';

import 'golden_harness.dart';

class _Gallery extends StatelessWidget {
  const _Gallery();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final shape in ExpressiveShape.marks)
                for (final tone in MarkTone.values)
                  ShapeMark(style: MarkStyle(shape, tone), label: shape.name),
            ],
          ),
          const SizedBox(height: 24),
          const Row(
            children: [
              ExpressiveLoadingIndicator(),
              SizedBox(width: 16),
              Expanded(child: WavyProgressIndicator(value: 0.6)),
            ],
          ),
          const SizedBox(height: 24),
          ConnectedButtonGroup<int>(
            buttons: const [
              ConnectedButton(value: 0, label: 'All'),
              ConnectedButton(value: 1, label: 'Recent'),
              ConnectedButton(value: 2, label: 'Unassigned'),
            ],
            selected: 0,
            onSelected: (_) {},
          ),
          const SizedBox(height: 16),
          SplitButton(
            label: 'Allow once',
            onPressed: () {},
            items: [SplitButtonItem(label: 'Always allow', onPressed: () {})],
          ),
          const SizedBox(height: 24),
          SegmentedListGroup(
            title: 'Recent',
            children: [
              for (final (title, sub) in [
                ('Nightly backup', 'Approve the prune command?'),
                ('Irrigation schedule', 'Moved the 6:00 cycle to 5:30.'),
                ('Print queue stuck', 'Cleared the spooler.'),
              ])
                SegmentedTile(
                  title: title,
                  subtitle: sub,
                  leading: ShapeMark(
                    style: MarkStyle.forKey(title),
                    label: title,
                  ),
                  trailing: const Text('2 min'),
                  onTap: () {},
                ),
            ],
          ),
          const SizedBox(height: 16),
          SegmentedListGroup(
            children: [
              SegmentedTile(
                title: 'Color & theme',
                subtitle: 'Wallpaper colors',
                leading: const TonalIcon(Icons.palette_outlined),
                onTap: () {},
              ),
            ],
          ),
        ],
      ),
    );
  }
}

void main() {
  for (final variant in goldenMatrix) {
    testWidgets('expressive kit ${variant.name}', (tester) async {
      await pumpGolden(
        tester,
        const _Gallery(),
        variant: variant,
        size: const Size(412, 820),
        settle: false,
      );
      await matchGolden(tester, 'expressive/kit_${variant.name}.png');
    });
  }
}
