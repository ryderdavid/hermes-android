import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/widgets/hermes_components.dart';

import 'golden_harness.dart';

void main() {
  for (final variant in goldenMatrix) {
    testWidgets('error state ${variant.name}', (tester) async {
      await pumpGolden(
        tester,
        Scaffold(
          appBar: AppBar(title: const Text('Cron Jobs')),
          body: Center(
            child: ErrorState(
              title: 'Failed to load cron jobs',
              message: 'Exception: Dashboard not reachable',
              onRetry: () {},
            ),
          ),
        ),
        variant: variant,
        size: const Size(412, 520),
      );
      await matchGolden(tester, 'states/error_${variant.name}.png');
    });

    testWidgets('empty state ${variant.name}', (tester) async {
      await pumpGolden(
        tester,
        Scaffold(
          appBar: AppBar(title: const Text('Chats')),
          body: Center(
            child: EmptyState(
              icon: Icons.chat_bubble_outline,
              title: 'No chats yet',
              message: 'Start a conversation with Hermes.',
              actionLabel: 'New chat',
              onAction: () {},
            ),
          ),
        ),
        variant: variant,
        size: const Size(412, 520),
      );
      await matchGolden(tester, 'states/empty_${variant.name}.png');
    });
  }
}
