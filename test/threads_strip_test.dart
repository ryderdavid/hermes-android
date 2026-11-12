import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/agent_thread.dart';
import 'package:hermes_android/core/theme/hermes_theme.dart';
import 'package:hermes_android/core/widgets/threads_strip.dart';
import 'package:hermes_android/l10n/app_localizations.dart';

AgentThread _thread(String id, String goal, AgentThreadState state) =>
    AgentThread(id: id, goal: goal, state: state);

Future<({List<String> opened, List<int> showAll})> _pump(
  WidgetTester tester,
  List<AgentThread> threads, {
  bool paused = false,
}) async {
  final opened = <String>[];
  final showAll = <int>[];
  await tester.pumpWidget(
    MaterialApp(
      theme: hermesTheme(Brightness.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Column(
          children: [
            ThreadsStrip(
              threads: threads,
              paused: paused,
              onOpenThread: (thread) => opened.add(thread.id),
              onShowAll: () => showAll.add(1),
            ),
            const Expanded(child: Text('chat')),
          ],
        ),
      ),
    ),
  );
  // A running thread's spinner never settles.
  await tester.pump(const Duration(milliseconds: 100));
  return (opened: opened, showAll: showAll);
}

void main() {
  testWidgets('takes no space when the chat has no threads', (tester) async {
    await _pump(tester, const []);

    expect(find.byKey(const Key('threads-strip')), findsNothing);
    expect(tester.getTopLeft(find.text('chat')).dy, 0);
  });

  testWidgets('shows one chip per thread and the All action', (tester) async {
    await _pump(tester, [
      _thread('a', 'Audit dependency licences', AgentThreadState.running),
      _thread('b', 'Draft release notes', AgentThreadState.done),
    ]);

    expect(find.byKey(const Key('threads-strip')), findsOneWidget);
    expect(find.text('Audit dependency licences'), findsOneWidget);
    expect(find.text('Draft release notes'), findsOneWidget);
    expect(find.text('All'), findsOneWidget);
    expect(
      tester.getSize(find.byKey(const Key('threads-strip'))).height,
      ThreadsStrip.height,
    );
  });

  testWidgets('keeps the order it is given: waiting threads first', (
    tester,
  ) async {
    await _pump(tester, [
      _thread('wait', 'Audit dependency licences', AgentThreadState.needsYou),
      _thread('run', 'Check CI matrix', AgentThreadState.running),
      _thread('done', 'Draft release notes', AgentThreadState.done),
    ]);

    final waiting = tester.getTopLeft(find.text('Audit dependency licences'));
    final running = tester.getTopLeft(find.text('Check CI matrix'));
    final done = tester.getTopLeft(find.text('Draft release notes'));
    expect(waiting.dx, lessThan(running.dx));
    expect(running.dx, lessThan(done.dx));
  });

  testWidgets('a waiting thread uses the emphasised container', (tester) async {
    await _pump(tester, [
      _thread('wait', 'Audit dependency licences', AgentThreadState.needsYou),
      _thread('run', 'Check CI matrix', AgentThreadState.running),
    ]);
    final scheme = Theme.of(
      tester.element(find.byKey(const Key('threads-strip'))),
    ).colorScheme;

    final waiting = tester.widget<InputChip>(
      find.byKey(const ValueKey<String>('thread-chip-wait')),
    );
    final running = tester.widget<InputChip>(
      find.byKey(const ValueKey<String>('thread-chip-run')),
    );
    expect(waiting.backgroundColor, scheme.tertiaryContainer);
    expect(running.backgroundColor, isNull);
    final label = tester.widget<Text>(find.text('Audit dependency licences'));
    expect(label.style?.color, scheme.onTertiaryContainer);

    // The state is announced, not only coloured.
    expect(
      find.bySemanticsLabel('Audit dependency licences, Needs you'),
      findsOneWidget,
    );
  });

  testWidgets('a chip opens its thread; All opens the sheet', (tester) async {
    final calls = await _pump(tester, [
      _thread('a', 'Audit dependency licences', AgentThreadState.running),
    ]);

    await tester.tap(find.text('Audit dependency licences'));
    await tester.tap(find.text('All'));

    expect(calls.opened, ['a']);
    expect(calls.showAll, hasLength(1));
  });

  testWidgets('only the newest finished threads keep a chip', (tester) async {
    await _pump(tester, [
      _thread('run', 'Running', AgentThreadState.running),
      for (var index = 0; index < 5; index++)
        _thread('done$index', 'Finished $index', AgentThreadState.done),
    ]);

    expect(find.text('Running'), findsOneWidget);
    expect(find.textContaining('Finished'), findsNWidgets(3));
    expect(find.text('Finished 0'), findsOneWidget);
    expect(find.text('Finished 3'), findsNothing);
  });

  testWidgets('says when new threads are paused', (tester) async {
    await _pump(tester, [
      _thread('a', 'Audit', AgentThreadState.running),
    ], paused: true);

    expect(find.byKey(const Key('threads-strip-paused')), findsOneWidget);
    expect(find.text('Paused'), findsOneWidget);
  });
}
