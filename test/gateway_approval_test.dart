import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/gateway_approval.dart';
import 'package:hermes_android/core/widgets/gateway_approval_dialog.dart';
import 'package:hermes_android/l10n/app_localizations.dart';

void main() {
  group('GatewayApprovalRequest', () {
    test('uses all official choices when the gateway allows them', () {
      final request = GatewayApprovalRequest.fromEventData({
        'command': 'echo fixture',
        'description': 'Run a fixture command',
        'allow_permanent': true,
        'choices': ['once', 'session', 'always', 'deny'],
      });

      expect(request.command, 'echo fixture');
      expect(request.allowPermanent, isTrue);
      expect(request.choices, GatewayApprovalChoice.values);
    });

    test('removes permanent approval when Hermes disallows it', () {
      final request = GatewayApprovalRequest.fromEventData({
        'allow_permanent': false,
        'choices': ['once', 'session', 'always'],
      });

      expect(request.allowPermanent, isFalse);
      expect(request.choices, [
        GatewayApprovalChoice.once,
        GatewayApprovalChoice.session,
        GatewayApprovalChoice.deny,
      ]);
    });

    test('smart denied approvals can only be run once or denied', () {
      final request = GatewayApprovalRequest.fromEventData({
        'smart_denied': true,
        'choices': ['once', 'session', 'always', 'deny'],
      });

      expect(request.choices, [
        GatewayApprovalChoice.once,
        GatewayApprovalChoice.deny,
      ]);
    });

    test('falls back to the official non-permanent choices', () {
      final request = GatewayApprovalRequest.fromEventData({
        'allow_permanent': false,
        'choices': ['unknown'],
      });

      expect(request.choices, [
        GatewayApprovalChoice.once,
        GatewayApprovalChoice.session,
        GatewayApprovalChoice.deny,
      ]);
    });
  });

  group('GatewayApprovalDialog', () {
    testWidgets('sends allow once and closes only after success', (
      tester,
    ) async {
      GatewayApprovalChoice? sentChoice;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<bool>(
                  context: context,
                  builder: (_) => GatewayApprovalDialog(
                    request: GatewayApprovalRequest.fromEventData({
                      'command': 'echo fixture',
                      'description': 'Run the fixture command',
                      'choices': ['once', 'deny'],
                    }),
                    onRespond: (choice) async => sentChoice = choice,
                  ),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(find.text('echo fixture'), findsOneWidget);

      await tester.tap(find.byKey(const Key('approval-once')));
      await tester.pumpAndSettle();

      expect(sentChoice, GatewayApprovalChoice.once);
      expect(find.text('Approval needed'), findsNothing);
    });

    testWidgets('requires a second confirmation for permanent approval', (
      tester,
    ) async {
      var sends = 0;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: GatewayApprovalDialog(
              request: GatewayApprovalRequest.fromEventData({
                'command': 'echo fixture',
                'choices': ['always', 'deny'],
              }),
              onRespond: (_) async => sends++,
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('approval-always')));
      await tester.pump();
      expect(sends, 0);
      expect(find.text('Confirm always allow'), findsOneWidget);

      await tester.tap(find.byKey(const Key('approval-always')));
      await tester.pump();
      expect(sends, 1);
    });

    testWidgets('opens as a bottom sheet with Deny and a split Allow', (
      tester,
    ) async {
      final sent = <GatewayApprovalChoice>[];
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => GatewayApprovalDialog.show(
                  context,
                  request: GatewayApprovalRequest.fromEventData({
                    'command': 'rm -rf build',
                    'choices': ['once', 'session', 'always', 'deny'],
                  }),
                  onRespond: (choice) async => sent.add(choice),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byKey(const Key('approval-deny')), findsOneWidget);
      // The narrowest grant is the primary half; broader ones wait in the menu.
      expect(find.byKey(const Key('approval-once')), findsOneWidget);
      expect(find.byKey(const Key('approval-session')), findsNothing);
      expect(find.byKey(const Key('approval-always')), findsNothing);

      await tester.tap(find.byKey(const Key('approval-more')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('approval-session')), findsOneWidget);
      expect(
        find.text('Allow matching commands until this Hermes session ends.'),
        findsOneWidget,
      );

      // "Always" from the menu still asks for a second, deliberate tap.
      await tester.tap(find.byKey(const Key('approval-always')));
      await tester.pumpAndSettle();
      expect(sent, isEmpty);
      expect(find.text('Confirm always allow'), findsOneWidget);

      await tester.tap(find.byKey(const Key('approval-always')));
      await tester.pumpAndSettle();
      expect(sent, [GatewayApprovalChoice.always]);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('the sheet cannot be swiped or tapped away', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => GatewayApprovalDialog.show(
                  context,
                  request: GatewayApprovalRequest.fromEventData({
                    'command': 'echo fixture',
                    'choices': ['once', 'deny'],
                  }),
                  onRespond: (_) async {},
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();

      await tester.tapAt(const Offset(10, 10));
      await tester.pumpAndSettle();
      expect(find.text('Approval needed'), findsOneWidget);
    });

    testWidgets('keeps the dialog open when the gateway rejects a response', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: GatewayApprovalDialog(
              request: GatewayApprovalRequest.fromEventData({
                'choices': ['once', 'deny'],
              }),
              onRespond: (_) async => throw Exception('fixture failure'),
            ),
          ),
        ),
      );

      await tester.tap(find.byKey(const Key('approval-once')));
      await tester.pumpAndSettle();

      expect(find.byKey(const Key('approval-error')), findsOneWidget);
      expect(find.byKey(const Key('approval-deny')), findsOneWidget);
    });
  });
}
