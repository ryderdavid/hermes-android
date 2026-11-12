import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/agent_thread.dart';
import 'package:hermes_android/core/services/agent_threads_controller.dart';
import 'package:hermes_android/core/services/thread_wire.dart';
import 'package:hermes_android/core/theme/hermes_theme.dart';
import 'package:hermes_android/core/widgets/threads_sheet.dart';
import 'package:hermes_android/l10n/app_localizations.dart';

import 'support/fake_threads_gateway.dart';

final _now = DateTime.utc(2026, 11, 11, 14, 30);

Future<({AgentThreadsController controller, List<String> opened})> _open(
  WidgetTester tester,
  FakeThreadsGateway gateway, {
  bool seed = true,
}) async {
  final controller = AgentThreadsController(
    gateway: gateway,
    clock: () => _now,
  );
  addTearDown(controller.dispose);
  if (seed) await controller.seed();
  final opened = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: hermesTheme(Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showThreadsSheet(
              context,
              controller: controller,
              onOpenThread: (thread) => opened.add(thread.id),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  // Spinners never settle; step through the sheet's entrance instead.
  for (var frame = 0; frame < 12; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
  return (controller: controller, opened: opened);
}

Future<void> _frames(WidgetTester tester) async {
  for (var frame = 0; frame < 12; frame++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

FakeThreadsGateway _gateway() => FakeThreadsGateway()
  ..roster = ThreadRosterSnapshot(
    threads: [
      rosterRow(
        'licences',
        goal: 'Audit dependency licences',
        tools: 7,
        startedAt: _now.millisecondsSinceEpoch / 1000 - 120,
      ),
      rosterRow(
        'ci',
        goal: 'Check CI matrix',
        tools: 3,
        startedAt: _now.millisecondsSinceEpoch / 1000 - 60,
      ),
    ],
  )
  ..status = const DelegationStatusSnapshot(
    activeCount: 2,
    paused: false,
    maxConcurrent: 3,
    model: 'claude-sonnet-5-5',
  );

void main() {
  testWidgets('states how many slots are in use out of the limit', (
    tester,
  ) async {
    await _open(tester, _gateway());

    expect(
      tester.widget<Text>(find.byKey(const Key('threads-sheet-usage'))).data,
      '2 of 3 slots in use · claude-sonnet-5-5',
    );
    expect(find.text('Audit dependency licences'), findsOneWidget);
    expect(find.text('Running · 7 tools · 2m 0s'), findsOneWidget);
    expect(find.text('Running · 3 tools · 1m 0s'), findsOneWidget);
  });

  testWidgets('re-reads slot usage each time it opens', (tester) async {
    final gateway = _gateway();
    await _open(tester, gateway);

    expect(gateway.callCount('status'), 2);
  });

  testWidgets('stop interrupts that thread only', (tester) async {
    final gateway = _gateway();
    final sheet = await _open(tester, gateway);

    await tester.tap(find.byKey(const ValueKey<String>('thread-stop-ci')));
    await _frames(tester);

    expect(gateway.calls.where((c) => c.startsWith('interrupt')), [
      'interrupt ci',
    ]);
    expect(sheet.controller.thread('ci')!.state, AgentThreadState.stopped);
    expect(
      sheet.controller.thread('licences')!.state,
      AgentThreadState.running,
    );
    // The stopped thread moved to the earlier list.
    expect(find.text('Earlier threads'), findsOneWidget);
    expect(find.text('1 finished in this chat'), findsOneWidget);
  });

  testWidgets('Stop all asks first; cancelling stops nothing', (tester) async {
    final gateway = _gateway();
    await _open(tester, gateway);

    await tester.tap(find.byKey(const Key('threads-stop-all')));
    await _frames(tester);
    expect(find.text('Stop all threads?'), findsOneWidget);
    expect(
      find.text('This interrupts all 2 running threads in this chat.'),
      findsOneWidget,
    );

    await tester.tap(find.text('Cancel'));
    await _frames(tester);

    expect(gateway.callCount('interrupt'), 0);
  });

  testWidgets('Stop all, confirmed, interrupts every running thread', (
    tester,
  ) async {
    final gateway = _gateway();
    final sheet = await _open(tester, gateway);

    await tester.tap(find.byKey(const Key('threads-stop-all')));
    await _frames(tester);
    await tester.tap(find.byKey(const Key('threads-stop-all-confirm')));
    await _frames(tester);

    expect(gateway.calls.where((c) => c.startsWith('interrupt')), [
      'interrupt licences',
      'interrupt ci',
    ]);
    expect(sheet.controller.activeThreads, isEmpty);
    expect(sheet.controller.threads.map((thread) => thread.state).toSet(), {
      AgentThreadState.stopped,
    });
    // Nothing left to stop.
    expect(
      tester
          .widget<TextButton>(find.byKey(const Key('threads-stop-all')))
          .onPressed,
      isNull,
    );
  });

  testWidgets('pause says it is gateway-wide and calls delegation.pause', (
    tester,
  ) async {
    final gateway = _gateway();
    final sheet = await _open(tester, gateway);

    expect(find.text('Pause new threads'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('threads-pause-scope'))).data,
      'Pauses new threads for every chat on this gateway. '
      'Running threads keep going.',
    );

    await tester.tap(find.byKey(const Key('threads-pause')));
    await _frames(tester);

    expect(gateway.calls, contains('pause true'));
    expect(sheet.controller.paused, isTrue);
    expect(find.text('Resume new threads'), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('threads-pause-scope'))).data,
      'New threads are paused for every chat on this gateway.',
    );

    await tester.tap(find.byKey(const Key('threads-pause')));
    await _frames(tester);
    expect(gateway.calls, contains('pause false'));
    expect(sheet.controller.paused, isFalse);
  });

  testWidgets('earlier threads expand, and a row opens its thread', (
    tester,
  ) async {
    final gateway = _gateway();
    final sheet = await _open(tester, gateway);
    sheet.controller.applyEvent(ThreadEventType.complete, {
      'subagent_id': 'ci',
      'goal': 'Check CI matrix',
      'status': 'completed',
      'tool_count': 5,
      'duration_seconds': 95.0,
    });
    await _frames(tester);

    expect(find.text('Check CI matrix'), findsNothing);
    await tester.tap(find.byKey(const Key('threads-earlier')));
    await _frames(tester);
    expect(find.text('Check CI matrix'), findsOneWidget);
    expect(find.text('Done · 5 tools · 1m 35s'), findsOneWidget);

    await tester.tap(find.text('Check CI matrix'));
    await _frames(tester);

    expect(sheet.opened, ['ci']);
    // The sheet closed before the thread opened.
    expect(find.text('Threads'), findsNothing);
  });

  testWidgets('a gateway failure is reported, not thrown', (tester) async {
    final gateway = _gateway();
    await _open(tester, gateway);
    gateway.failures['pause'] = StateError('socket closed');

    await tester.tap(find.byKey(const Key('threads-pause')));
    await _frames(tester);

    expect(find.textContaining("Couldn't reach the gateway"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('without slot status it counts the active threads', (
    tester,
  ) async {
    final gateway = _gateway()..failures['status'] = StateError('no status');
    final controller = AgentThreadsController(
      gateway: gateway,
      clock: () => _now,
    );
    addTearDown(controller.dispose);
    await controller.seed();
    gateway.failures['status'] = StateError('no status');
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ThreadsSheet(controller: controller, onOpenThread: (_) {}),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      tester.widget<Text>(find.byKey(const Key('threads-sheet-usage'))).data,
      '2 active threads',
    );
  });
}
