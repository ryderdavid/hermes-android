import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/gateway_approval.dart';
import 'package:hermes_android/core/widgets/gateway_approval_dialog.dart';
import 'package:hermes_android/l10n/app_localizations.dart';

Future<List<GatewayApprovalChoice>> _open(
  WidgetTester tester,
  Map<String, dynamic> data,
) async {
  final answers = <GatewayApprovalChoice>[];
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => GatewayApprovalDialog.show(
              context,
              request: GatewayApprovalRequest.fromEventData(data),
              onRespond: (choice) async => answers.add(choice),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
  return answers;
}

void main() {
  testWidgets('names the thread that raised the approval', (tester) async {
    final answers = await _open(tester, {
      'description': 'Re-run the failing Android jobs.',
      'command': 'gh run rerun 18734 --failed',
      'choices': ['once', 'deny'],
      'subagent_id': 'sa-0',
      'goal': 'Check CI matrix',
    });

    expect(find.byKey(const Key('approval-thread')), findsOneWidget);
    expect(find.text('From thread: Check CI matrix'), findsOneWidget);
    expect(find.text('Re-run the failing Android jobs.'), findsOneWidget);

    await tester.tap(find.text('Allow once'));
    await tester.pumpAndSettle();
    expect(answers, [GatewayApprovalChoice.once]);
  });

  testWidgets('a thread without a goal still reads as a thread', (
    tester,
  ) async {
    await _open(tester, {'command': 'ls', 'subagent_id': 'sa-0'});

    expect(find.text('From thread: Thread'), findsOneWidget);
  });

  testWidgets('the main agent\'s approval has no thread line', (tester) async {
    await _open(tester, {
      'description': 'Delete a file',
      'command': 'rm file',
      'choices': ['once', 'deny'],
    });

    expect(find.byKey(const Key('approval-thread')), findsNothing);
    expect(find.textContaining('From thread'), findsNothing);
  });
}
