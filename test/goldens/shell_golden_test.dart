import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/widgets/hermes_shell.dart';

import 'app_golden_harness.dart';
import 'golden_harness.dart';

class _FakePane extends StatelessWidget {
  const _FakePane(this.destination);

  final HermesDestination destination;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(destination.name)),
      body: ListView(
        children: [
          for (var i = 1; i <= 4; i++)
            ListTile(
              leading: const Icon(Icons.chat_bubble_outline),
              title: Text('Conversation $i'),
              subtitle: const Text('Last message preview'),
            ),
        ],
      ),
    );
  }
}

void main() {
  for (final variant in goldenMatrix) {
    for (final (form, size) in [
      ('phone', goldenPhoneSize),
      ('tablet', const Size(1280, 800)),
    ]) {
      testWidgets('shell $form ${variant.name}', (tester) async {
        await pumpGolden(
          tester,
          HermesShell(
            initialDestination: HermesDestination.home,
            badges: const {HermesDestination.activity: 3},
            builder: (context, destination) => _FakePane(destination),
          ),
          variant: variant,
          size: size,
        );
        await matchGolden(tester, 'shell/${form}_${variant.name}.png');
      });
    }

    testWidgets('connection dialog ${variant.name}', (tester) async {
      await pumpGoldenApp(tester, variant: variant);
      await tester.tap(find.byTooltip('Add Connection'));
      await tester.pumpAndSettle();
      await matchGolden(tester, 'fields/connection_dialog_${variant.name}.png');
    });
  }
}
