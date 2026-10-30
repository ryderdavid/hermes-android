import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/gateway_approval.dart';
import 'package:hermes_android/core/widgets/gateway_approval_dialog.dart';

import 'golden_harness.dart';

void main() {
  for (final variant in goldenMatrix) {
    testWidgets('approval sheet ${variant.name}', (tester) async {
      await pumpGolden(
        tester,
        Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: TextButton(
                onPressed: () => GatewayApprovalDialog.show(
                  context,
                  request: GatewayApprovalRequest.fromEventData({
                    'description':
                        'Hermes wants to free space on the backup '
                        'disk before re-running the job.',
                    'command': 'restic forget --keep-daily 7 --prune',
                    'choices': ['once', 'session', 'always', 'deny'],
                  }),
                  onRespond: (_) async {},
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
        variant: variant,
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await matchGolden(tester, 'screens/approval_sheet_${variant.name}.png');
    });
  }
}
