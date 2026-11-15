import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/screens/workspace_screen.dart';
import 'package:hermes_android/core/services/android_launch_intent_service.dart';
import 'package:hermes_android/core/services/android_share_intent_service.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/core/services/turn_notification_service.dart';
import 'package:hermes_android/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemoryCredentialStore implements CredentialStore {
  final Map<String, String> _values = {};

  @override
  Future<void> delete(String key) async => _values.remove(key);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  String? readCached(String key) => _values[key];

  @override
  Future<void> write(String key, String value) async => _values[key] = value;
}

/// The workspace keeps polling, so advance time rather than settle.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

int _workspaces(WidgetTester tester) =>
    find.byType(WorkspaceScreen, skipOffstage: false).evaluate().length;

NotificationResponse _approvalTap(String connectionId, String sessionId) =>
    NotificationResponse(
      id: 41,
      actionId: 'approve',
      payload: jsonEncode({
        'connectionId': connectionId,
        'sessionId': sessionId,
        'requestId': 'request-41',
      }),
      notificationResponseType:
          NotificationResponseType.selectedNotificationAction,
    );

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    pendingNotificationApprovals.value = const [];
  });

  tearDown(() {
    pendingNotificationApprovals.value = const [];
    notificationResponseHandler = null;
  });

  testWidgets(
    'approval actions retain the exact saved profile on a shared endpoint',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final manager = await ConnectionManager.create(
        prefs,
        credentialStore: _MemoryCredentialStore(),
      );
      await manager.saveConnection(
        'Profile A',
        '127.0.0.1',
        1,
        'key-a',
        gatewayProfile: 'alpha',
      );
      await manager.saveConnection(
        'Profile B',
        '127.0.0.1',
        1,
        'key-b',
        gatewayProfile: 'beta',
      );
      final profiles = manager.getConnections();
      final target = profiles.firstWhere(
        (connection) => connection.gatewayProfile == 'beta',
      );
      final sibling = profiles.firstWhere(
        (connection) => connection.gatewayProfile == 'alpha',
      );
      expect(target.baseUrl, sibling.baseUrl);
      expect(target.id, isNot(sibling.id));

      await tester.pumpWidget(HermesApp(connManager: manager));
      await tester.pump();

      notificationResponseHandler!(
        NotificationResponse(
          id: 7,
          actionId: 'approve',
          payload: jsonEncode({
            'connectionId': target.id,
            'sessionId': 'shared-session',
            'requestId': 'request-7',
          }),
          notificationResponseType:
              NotificationResponseType.selectedNotificationAction,
        ),
      );
      await tester.pump();

      expect(pendingNotificationApprovals.value, hasLength(1));
      expect(pendingNotificationApprovals.value.single.connectionId, target.id);
      expect(
        pendingNotificationApprovals.value.single.connectionId,
        isNot(sibling.id),
      );

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('a cold-launch notification tap delivered twice is handled once', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final manager = await ConnectionManager.create(
      prefs,
      credentialStore: _MemoryCredentialStore(),
    );
    await manager.saveConnection(
      'Profile A',
      '127.0.0.1',
      1,
      'key-a',
    );
    final target = manager.getConnections().single;
    await tester.pumpWidget(HermesApp(connManager: manager));
    await tester.pump();

    // The same tap arrives via launch details AND onDidReceiveNotificationResponse.
    NotificationResponse response() => NotificationResponse(
      id: 11,
      actionId: 'approve',
      payload: jsonEncode({
        'connectionId': target.id,
        'sessionId': 's-11',
        'requestId': 'request-11',
      }),
      notificationResponseType:
          NotificationResponseType.selectedNotificationAction,
    );
    notificationResponseHandler!(response());
    await tester.pump();
    notificationResponseHandler!(response());
    await tester.pump();

    // One pending approval, not two: the duplicate tap must not re-run.
    expect(pendingNotificationApprovals.value, hasLength(1));
    expect(pendingNotificationApprovals.value.single.requestId, 'request-11');

    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'the approval snackbar Review action does not stack a second route '
    'over the notification-opened screen',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final manager = await ConnectionManager.create(
        prefs,
        credentialStore: _MemoryCredentialStore(),
      );
      await manager.saveConnection('Local', '127.0.0.1', 1, 'key');
      final target = manager.getConnections().single;
      await tester.pumpWidget(HermesApp(connManager: manager));
      await _settle(tester);
      expect(_workspaces(tester), 0);

      // Cold-open tap: session fetch fails offline, so the fallback
      // notification-workspace route is pushed and the approval stays pending.
      notificationResponseHandler!(_approvalTap(target.id, 's-41'));
      await _settle(tester);
      expect(_workspaces(tester), 1);
      expect(pendingNotificationApprovals.value, hasLength(1));
      expect(find.text('Review'), findsOneWidget);

      // The app-wide "Approval needed" snackbar outlives the sheet; its
      // Review action must not push a second copy of the same session.
      await tester.tap(find.text('Review'));
      await _settle(tester);
      expect(_workspaces(tester), 1);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a share intent arriving after a notification push does not cover it',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final manager = await ConnectionManager.create(
        prefs,
        credentialStore: _MemoryCredentialStore(),
      );
      await manager.saveConnection('Local', '127.0.0.1', 1, 'key');
      final target = manager.getConnections().single;
      final share = AndroidShareIntentService();
      await tester.pumpWidget(
        HermesApp(connManager: manager, shareIntents: share),
      );
      await _settle(tester);

      notificationResponseHandler!(_approvalTap(target.id, 's-41'));
      await _settle(tester);
      expect(_workspaces(tester), 1);

      // A share delivered after the notification already navigated must not
      // stack a workspace on top of the notification-opened chat/sheet.
      share.pendingShare.value = const AndroidSharePayload(text: 'hello');
      await _settle(tester);
      expect(_workspaces(tester), 1);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'a quick-chat intent arriving after a notification push does not cover it',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final manager = await ConnectionManager.create(
        prefs,
        credentialStore: _MemoryCredentialStore(),
      );
      await manager.saveConnection('Local', '127.0.0.1', 1, 'key');
      final target = manager.getConnections().single;
      final launch = AndroidLaunchIntentService();
      await tester.pumpWidget(
        HermesApp(connManager: manager, launchIntents: launch),
      );
      await _settle(tester);

      notificationResponseHandler!(_approvalTap(target.id, 's-41'));
      await _settle(tester);
      expect(_workspaces(tester), 1);

      launch.pendingQuickChat.value = true;
      await _settle(tester);
      expect(_workspaces(tester), 1);

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
