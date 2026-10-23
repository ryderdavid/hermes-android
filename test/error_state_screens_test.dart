import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/screens/chat_screen.dart';
import 'package:hermes_android/core/screens/cron_screen.dart';
import 'package:hermes_android/core/screens/memory_screen.dart';
import 'package:hermes_android/core/screens/session_list_screen.dart';
import 'package:hermes_android/core/screens/settings_screen.dart';
import 'package:hermes_android/core/screens/skills_screen.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/core/services/gateway_turn_application_controller.dart';
import 'package:hermes_android/core/theme/hermes_theme.dart';
import 'package:hermes_android/core/widgets/hermes_components.dart';
import 'package:hermes_android/l10n/app_localizations.dart';
import 'package:hermes_android/main.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A dashboard that never answers, so dashboard-backed screens fail to load.
final _offline = SavedConnection(
  id: 'offline-dashboard',
  label: 'Offline dashboard',
  host: '127.0.0.1',
  port: 8642,
  dashboardPortOverride: 1,
  apiKey: 'test-only',
);

/// A gateway whose health check passes but whose data endpoints fail.
class _FailingGateway extends http.BaseClient {
  int dataRequests = 0;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.url.path.endsWith('/health')) {
      return _json({'status': 'ok'});
    }
    if (request.url.path.endsWith('/api/sessions') &&
        !request.url.queryParameters.containsKey('offset')) {
      // Health-check auth confirmation.
      return _json({'object': 'list', 'data': [], 'has_more': false});
    }
    dataRequests++;
    return _json({'error': 'boom'}, status: 500);
  }

  http.StreamedResponse _json(Map<String, dynamic> body, {int status = 200}) =>
      http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(body))),
        status,
        headers: {'content-type': 'application/json'},
      );
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: hermesTheme(Brightness.light),
      home: home,
    ),
  );
  await tester.pumpAndSettle();
}

/// The failure renders the shared ErrorState with [title] and one standard
/// tonal Retry button.
void _expectErrorState(WidgetTester tester, String title) {
  expect(find.byType(ErrorState), findsOneWidget);
  expect(find.text(title), findsOneWidget);
  expect(find.widgetWithText(FilledButton, 'Retry'), findsOneWidget);
  expect(find.byType(ElevatedButton), findsNothing);
  // 40dp visible button inside a 48dp touch target.
  final retry = find.widgetWithText(FilledButton, 'Retry');
  expect(tester.getSize(retry).height, 48);
  final surface = find.descendant(of: retry, matching: find.byType(Material));
  expect(tester.getSize(surface.first).height, 40);
}

/// A dashboard that answers every request with 503, counting them, so a
/// test can tell that Retry really fetched again.
class _DownDashboard {
  int requests = 0;

  late final http.Client client = MockClient((request) async {
    requests++;
    return http.Response('unavailable', 503);
  });

  /// Runs [body] with every `http.Client()` created inside it pointed here.
  Future<void> run(Future<void> Function() body) =>
      http.runWithClient(body, () => client);
}

Future<void> _retryRefetches(
  WidgetTester tester,
  _DownDashboard dashboard,
) async {
  final before = dashboard.requests;
  await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
  await tester.pumpAndSettle();
  expect(dashboard.requests, greaterThan(before));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('Cron failure shows ErrorState and retries', (tester) async {
    final dashboard = _DownDashboard();
    await dashboard.run(() async {
      await _pump(tester, CronScreen(connection: _offline));
      _expectErrorState(tester, 'Failed to load cron jobs');
      await _retryRefetches(tester, dashboard);
      _expectErrorState(tester, 'Failed to load cron jobs');
    });
  });

  testWidgets('Memory failure shows ErrorState and retries', (tester) async {
    final dashboard = _DownDashboard();
    await dashboard.run(() async {
      await _pump(tester, MemoryScreen(connection: _offline));
      _expectErrorState(tester, 'Failed to load memory');
      await _retryRefetches(tester, dashboard);
      _expectErrorState(tester, 'Failed to load memory');
    });
  });

  testWidgets('Skills failure shows ErrorState and retries', (tester) async {
    final dashboard = _DownDashboard();
    await dashboard.run(() async {
      await _pump(tester, SkillsScreen(connection: _offline));
      _expectErrorState(tester, 'Failed to load skills');
      await _retryRefetches(tester, dashboard);
      _expectErrorState(tester, 'Failed to load skills');
    });
  });

  testWidgets('Settings failure shows ErrorState above local controls', (
    tester,
  ) async {
    final dashboard = _DownDashboard();
    await dashboard.run(() async {
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(HermesApp(connManager: ConnectionManager(prefs)));
      await tester.pumpAndSettle();
      unawaited(
        Navigator.of(tester.element(find.byType(HomeScreen))).push(
          MaterialPageRoute<void>(
            builder: (_) => SettingsScreen(connection: _offline),
          ),
        ),
      );
      await tester.pumpAndSettle();

      _expectErrorState(tester, 'Failed to load settings');
      expect(find.text('Appearance'), findsOneWidget);
      await _retryRefetches(tester, dashboard);
      _expectErrorState(tester, 'Failed to load settings');
    });
  });

  testWidgets('Session list failure shows ErrorState and retries', (
    tester,
  ) async {
    final gateway = _FailingGateway();
    final controller = GatewayTurnApplicationController();
    await _pump(
      tester,
      SessionListScreen(
        connection: SavedConnection(
          id: 'failing',
          label: 'Failing',
          host: 'failing.fixture',
          port: 8642,
          apiKey: 'fixture-key',
        ),
        turnApplicationController: controller,
        testHttpClient: gateway,
      ),
    );

    _expectErrorState(tester, 'Connection issue');
    final before = gateway.dataRequests;
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(gateway.dataRequests, greaterThan(before));
    _expectErrorState(tester, 'Connection issue');
  });

  testWidgets('Chat history failure shows ErrorState and retries', (
    tester,
  ) async {
    final gateway = _FailingGateway();
    await _pump(
      tester,
      ChatScreen(
        connection: SavedConnection(
          id: 'failing',
          label: 'Failing',
          host: 'failing.fixture',
          port: 8642,
          apiKey: 'fixture-key',
        ),
        session: Session(
          id: 'session-1',
          title: 'Fixture chat',
          model: 'fixture-model',
          source: 'test',
          messageCount: 3,
          isActive: false,
          preview: '',
          startedAt: 1,
        ),
        testApiClient: ApiClient(
          baseUrl: 'http://failing.fixture',
          apiKey: 'fixture-key',
          httpClient: gateway,
        ),
      ),
    );

    _expectErrorState(tester, 'Failed to load messages');
    final before = gateway.dataRequests;
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pumpAndSettle();
    expect(gateway.dataRequests, greaterThan(before));
    _expectErrorState(tester, 'Failed to load messages');
  });
}
