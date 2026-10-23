import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

/// Every button type the app uses, at rest and disabled, so the M3 sizing
/// (40dp tall, fully rounded) is visible side by side.
class _ButtonGallery extends StatelessWidget {
  const _ButtonGallery();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Buttons')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton(onPressed: () {}, child: const Text('Filled')),
            FilledButton.tonal(onPressed: () {}, child: const Text('Tonal')),
            OutlinedButton(onPressed: () {}, child: const Text('Outlined')),
            TextButton(onPressed: () {}, child: const Text('Text')),
            ElevatedButton(onPressed: () {}, child: const Text('Elevated')),
            FilledButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
            const FilledButton(onPressed: null, child: Text('Disabled')),
            const OutlinedButton(onPressed: null, child: Text('Disabled')),
            SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('System')),
                ButtonSegment(value: 1, label: Text('Dark')),
                ButtonSegment(value: 2, label: Text('Light')),
              ],
              selected: const {0},
              onSelectionChanged: (_) {},
            ),
          ],
        ),
      ),
    );
  }
}

/// App bar, list rows, switch, chips, a filled field and a FAB.
class _ComponentGallery extends StatelessWidget {
  const _ComponentGallery();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Components'),
        actions: [IconButton(onPressed: () {}, icon: const Icon(Icons.search))],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.add),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: [
          const ListTile(
            leading: Icon(Icons.wifi),
            title: Text('Connection'),
            subtitle: Text('Miniserver · 8642'),
          ),
          SwitchListTile(
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            value: true,
            onChanged: (_) {},
          ),
          SwitchListTile(
            secondary: const Icon(Icons.terminal),
            title: const Text('Verbose mode'),
            value: false,
            onChanged: (_) {},
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Model'),
                  onPressed: () {},
                ),
                FilterChip(
                  label: const Text('Spoken reply'),
                  selected: true,
                  onSelected: (_) {},
                ),
                const Chip(label: Text('Idle')),
              ],
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                labelText: 'Host',
                hintText: 'https://example.ts.net',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void main() {
  for (final variant in goldenMatrix) {
    testWidgets('buttons ${variant.name}', (tester) async {
      await pumpGolden(
        tester,
        const _ButtonGallery(),
        variant: variant,
        size: const Size(412, 300),
      );
      await matchGolden(tester, 'components/buttons_${variant.name}.png');
    });

    testWidgets('components ${variant.name}', (tester) async {
      await pumpGolden(
        tester,
        const _ComponentGallery(),
        variant: variant,
        size: const Size(412, 560),
      );
      await matchGolden(tester, 'components/components_${variant.name}.png');
    });

    testWidgets('dialog and snackbar ${variant.name}', (tester) async {
      await pumpGolden(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Chat renamed'),
                      action: SnackBarAction(label: 'Undo', onPressed: () {}),
                    ),
                  );
                  showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Delete chat?'),
                      content: const Text(
                        'This removes the chat from this device.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () {},
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {},
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
        variant: variant,
        size: const Size(412, 600),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await matchGolden(tester, 'components/dialog_${variant.name}.png');
    });

    testWidgets('bottom sheet ${variant.name}', (tester) async {
      await pumpGolden(
        tester,
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  builder: (_) => const Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Rename'),
                      ),
                      ListTile(
                        leading: Icon(Icons.push_pin_outlined),
                        title: Text('Pin'),
                      ),
                      SizedBox(height: 16),
                    ],
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
        variant: variant,
        size: const Size(412, 500),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await matchGolden(tester, 'components/sheet_${variant.name}.png');
    });
  }

  testWidgets('components at 1.3x text do not clip', (tester) async {
    await pumpGolden(
      tester,
      const _ComponentGallery(),
      variant: goldenMatrix.first,
      size: const Size(412, 700),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    await matchGolden(tester, 'components/components_text130.png');
  });
}
