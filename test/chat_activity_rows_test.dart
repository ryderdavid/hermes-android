import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/screens/chat_screen.dart';
import 'package:hermes_android/core/services/connection_manager.dart';
import 'package:hermes_android/core/services/desktop_gateway_client.dart';
import 'package:hermes_android/core/services/ws_client.dart';
import 'package:hermes_android/core/widgets/activity_detail_sheet.dart';
import 'package:hermes_android/core/widgets/activity_row.dart';
import 'package:hermes_android/core/widgets/turn_fold.dart';
import 'package:hermes_android/l10n/app_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Activity rows, turn folding and the detail sheet driven through the real
/// `ChatScreen`: live gateway events in, list order out.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'verbose_mode': false});
  });

  group('live order (D2)', () {
    testWidgets('text, tool, text: the row sits between the two messages', (
      tester,
    ) async {
      final remote = await _startRemoteTurn(tester, 'text-tool-text');

      remote.emit('message.delta', {'text': 'Looking at it'});
      remote.emit('tool.start', _terminal('call-1'));
      remote.emit('message.delta', {'text': 'Found it'});
      await _frames(tester);

      expect(_order(tester), ['bot:Looking at it', 'row', 'bot:Found it']);
      expect(tester.takeException(), isNull);

      remote.emit('tool.complete', {..._terminal('call-1'), 'duration_s': 1});
      remote.emit('message.complete', {'text': 'Found it'});
      remote.finish();
      await tester.pumpAndSettle();

      // The finished turn folds; the final answer stays.
      expect(_order(tester), ['fold', 'bot:Found it']);
      expect(_bubble('Looking at it'), findsNothing);
    });

    testWidgets('a tool before any text sits above the text that follows', (
      tester,
    ) async {
      final remote = await _startRemoteTurn(tester, 'tool-first');

      remote.emit('tool.start', _terminal('call-1'));
      await _frames(tester);
      expect(_order(tester), ['row']);

      remote.emit('message.delta', {'text': 'Here is what I found'});
      await _frames(tester);
      expect(_order(tester), ['row', 'bot:Here is what I found']);
    });

    testWidgets('two tools, an interim message, a third tool; '
        'unfolding the finished turn shows the same order', (tester) async {
      final remote = await _startRemoteTurn(tester, 'spec-order');

      remote.emit('tool.start', _terminal('call-1'));
      remote.emit('tool.complete', _terminal('call-1'));
      remote.emit('tool.start', _terminal('call-2'));
      remote.emit('tool.complete', _terminal('call-2'));
      remote.emit('message.delta', {'text': 'Halfway there'});
      remote.emit('message.interim', {
        'text': 'Halfway there',
        'already_streamed': true,
      });
      remote.emit('tool.start', _readFile('call-3'));
      await _frames(tester);
      expect(_order(tester), ['row', 'row', 'bot:Halfway there', 'row']);

      remote.emit('tool.complete', _readFile('call-3'));
      remote.emit('message.delta', {'text': 'All done'});
      remote.emit('message.complete', {'text': 'All done'});
      remote.finish();
      await tester.pumpAndSettle();
      expect(_order(tester), ['fold', 'bot:All done']);

      await tester.tap(find.byType(TurnFoldLine));
      await tester.pumpAndSettle();
      expect(_order(tester), [
        'fold',
        'row', // "Ran 2 commands"
        'bot:Halfway there',
        'row',
        'bot:All done',
      ]);
      expect(find.text('Ran 2 commands'), findsOneWidget);

      await tester.tap(find.byType(TurnFoldLine));
      await tester.pumpAndSettle();
      expect(_order(tester), ['fold', 'bot:All done']);
    });

    testWidgets('a tool that is still being written is anchored, and its '
        'start closes the message that streamed meanwhile', (tester) async {
      final remote = await _startRemoteTurn(tester, 'generating');

      remote.emit('tool.generating', {'tool_id': 'call-1', 'name': 'terminal'});
      remote.emit('message.delta', {'text': 'Let me check'});
      remote.emit('tool.start', _terminal('call-1'));
      remote.emit('message.delta', {'text': 'Checked'});
      await _frames(tester);

      expect(_order(tester), ['bot:Let me check', 'row', 'bot:Checked']);
    });

    testWidgets('an interim event for text a tool start already closed does '
        'not repeat it', (tester) async {
      final remote = await _startRemoteTurn(tester, 'late-interim');

      remote.emit('message.delta', {'text': 'Looking at it'});
      remote.emit('tool.start', _terminal('call-1'));
      remote.emit('message.interim', {
        'text': 'Looking at it',
        'already_streamed': true,
      });
      await _frames(tester);
      expect(_order(tester), ['bot:Looking at it', 'row']);

      remote.emit('tool.complete', _terminal('call-1'));
      remote.emit('message.delta', {'text': 'Found it'});
      remote.emit('message.complete', {'text': 'Found it'});
      remote.finish();
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TurnFoldLine));
      await tester.pumpAndSettle();
      expect(_order(tester), [
        'fold',
        'bot:Looking at it',
        'row',
        'bot:Found it',
      ]);
    });

    testWidgets('a previewed completion still settles on the interim it '
        'matches after a tool start closed that interim', (tester) async {
      final remote = await _startRemoteTurn(tester, 'previewed');

      remote.emit('message.delta', {'text': 'The answer is 7'});
      remote.emit('tool.start', _terminal('call-1'));
      remote.emit('tool.complete', _terminal('call-1'));
      remote.emit('message.complete', {
        'text': 'The answer is 7',
        'response_previewed': true,
      });
      remote.finish();
      await tester.pumpAndSettle();

      expect(_bubble('The answer is 7'), findsOneWidget);
      expect(find.byTooltip('Send'), findsOneWidget);
    });

    testWidgets('reasoning before a tool stays above its row', (tester) async {
      final remote = await _startRemoteTurn(tester, 'reasoning-order');

      remote.emit('reasoning.delta', {'text': 'Checking the service binding'});
      await _frames(tester);
      expect(find.text('Checking the service binding'), findsOneWidget);

      remote.emit('tool.start', _terminal('call-1'));
      remote.emit('reasoning.available', {
        'text': 'Checking the service binding first.',
      });
      remote.emit('reasoning.delta', {'text': 'Now reading the output'});
      await _frames(tester);

      final rows = tester.widgetList<ActivityRow>(find.byType(ActivityRow));
      expect(rows.map((row) => row.activity?.name ?? row.label), [
        'Checking the service binding first.',
        'terminal',
        'Now reading the output',
      ]);
    });

    testWidgets('REST: text, tool, text keeps the row between the messages', (
      tester,
    ) async {
      final client = _ControlledChatHttpClient(const []);
      await _pumpChat(tester, client: client, id: 'rest-order');
      await tester.enterText(find.byType(TextField), 'go');
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      await client.postStarted.future;

      client.emitToken('Looking at it');
      await _frames(tester);
      client.emitToolProgress({'tool': 'terminal', 'label': 'flutter test'});
      await _frames(tester);
      client.emitToken('Found it');
      await _frames(tester);
      expect(_order(tester), ['bot:Looking at it', 'row', 'bot:Found it']);

      // The finished frame of the same call must not move its row below the
      // text that streamed while it ran.
      client.emitToolProgress({
        'tool': 'terminal',
        'label': 'flutter test',
        'status': 'completed',
      });
      await _frames(tester);
      expect(_order(tester), ['bot:Looking at it', 'row', 'bot:Found it']);

      client.finish([
        {'id': 1, 'role': 'user', 'content': 'go'},
        {'id': 2, 'role': 'assistant', 'content': 'Looking at it'},
        {'id': 3, 'role': 'tool', 'name': 'terminal', 'content': 'ok'},
        {'id': 4, 'role': 'assistant', 'content': 'Found it'},
      ]);
      await tester.pumpAndSettle();
      expect(_order(tester), ['fold', 'bot:Found it']);
    });
  });

  group('handoff to stored history', () {
    testWidgets('stored order takes over after a refresh, and the turn '
        'stays unfolded', (tester) async {
      final client = _ControlledChatHttpClient(const []);
      final remote = await _startRemoteTurn(tester, 'handoff', client: client);
      remote.emit('tool.start', _terminal('call-1'));
      remote.emit('tool.complete', _terminal('call-1'));
      remote.emit('message.delta', {'text': 'Halfway there'});
      remote.emit('tool.start', _readFile('call-2'));
      remote.emit('tool.complete', _readFile('call-2'));
      remote.emit('message.delta', {'text': 'All done'});
      remote.emit('message.complete', {'text': 'All done'});
      remote.finish();
      await tester.pumpAndSettle();

      await tester.tap(find.byType(TurnFoldLine));
      await tester.pumpAndSettle();
      const live = ['fold', 'row', 'bot:Halfway there', 'row', 'bot:All done'];
      expect(_order(tester), live);
      expect(_fold(tester).unfolded, isTrue);

      client.serverMessages = [
        {'id': 1, 'role': 'user', 'content': 'go', 'timestamp': 1792544000},
        _storedTool(2, 'call-1', 'terminal'),
        {'id': 3, 'role': 'assistant', 'content': 'Halfway there'},
        _storedTool(4, 'call-2', 'read_file'),
        {
          'id': 5,
          'role': 'assistant',
          'content': 'All done',
          'timestamp': 1792544144,
        },
      ];
      await tester.tap(find.byTooltip('Chat actions'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Refresh'));
      await tester.pumpAndSettle();

      // Same sequence from the stored rows, the choice carried from the
      // tool id to the stored user message, and the stored duration.
      expect(_order(tester), live);
      expect(_fold(tester).unfolded, isTrue);
      expect(find.text('Worked for 2m 24s'), findsOneWidget);
    });

    testWidgets('a turn loaded from history starts folded', (tester) async {
      await _pumpChat(
        tester,
        client: _ControlledChatHttpClient([
          {'id': 1, 'role': 'user', 'content': 'go'},
          _storedTool(2, 'call-1', 'terminal'),
          _storedTool(3, 'call-2', 'terminal'),
          {'id': 4, 'role': 'assistant', 'content': 'All done'},
        ]),
        id: 'from-history',
      );
      expect(_order(tester), ['fold', 'bot:All done']);
      // No timestamps: the line states the step count.
      expect(find.text('Worked through 2 steps'), findsOneWidget);
    });

    testWidgets('reconnect mid-turn: the detached reply lands once, in '
        'stored order', (tester) async {
      final client = _ControlledChatHttpClient(const []);
      final hook = TestDesktopConnectionHook();
      final submitted = Completer<void>();
      StreamCallback? events;
      await _pumpChat(
        tester,
        client: client,
        id: 'reconnect',
        connectionHook: hook,
        remoteSubmit:
            ({
              required sessionId,
              required text,
              required onEvent,
              required onSent,
            }) {
              events = onEvent;
              onSent();
              return submitted.future;
            },
      );
      hook.handler?.call(DesktopConnectionState.connected);
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'go');
      await tester.tap(find.byTooltip('Send'));
      await tester.pump();
      await tester.pump();

      events!(StreamEvent(type: 'message.delta', data: {'text': 'Looking'}));
      events!(StreamEvent(type: 'tool.start', data: _terminal('call-1')));
      await _frames(tester);
      expect(_order(tester), ['bot:Looking', 'row']);

      hook.handler?.call(DesktopConnectionState.reconnecting);
      await tester.pump();
      submitted.completeError(
        JsonRpcError('prompt.submit', 'Desktop gateway connection closed'),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      client.serverMessages = [
        {'id': 1, 'role': 'user', 'content': 'go'},
        {'id': 2, 'role': 'assistant', 'content': 'Looking'},
        _storedTool(3, 'call-1', 'terminal'),
        {'id': 4, 'role': 'assistant', 'content': 'Detached final reply'},
      ];
      hook.handler?.call(DesktopConnectionState.connected);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pumpAndSettle();
      await tester.pump(const Duration(milliseconds: 100));

      expect(_bubble('Detached final reply'), findsOneWidget);
      expect(_order(tester), ['fold', 'bot:Detached final reply']);
      await tester.tap(find.byType(TurnFoldLine));
      await tester.pumpAndSettle();
      expect(_order(tester), [
        'fold',
        'bot:Looking',
        'row',
        'bot:Detached final reply',
      ]);
      expect(tester.takeException(), isNull);
    });
  });

  group('folding (D6)', () {
    testWidgets('an unfolded turn stays unfolded after it scrolls off screen', (
      tester,
    ) async {
      await _pumpChat(
        tester,
        client: _ControlledChatHttpClient([
          {'id': 1, 'role': 'user', 'content': 'first question'},
          _storedTool(2, 'call-1', 'terminal'),
          _storedTool(3, 'call-2', 'read_file'),
          {'id': 4, 'role': 'assistant', 'content': 'first answer'},
          for (var index = 0; index < 24; index++)
            {
              'id': 10 + index,
              'role': index.isEven ? 'user' : 'assistant',
              'content':
                  'message $index\n${List.filled(5, 'filler').join('\n')}',
            },
        ]),
        id: 'scroll-away',
      );
      final controller = _listController(tester);
      controller.jumpTo(0);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(TurnFoldLine));
      await tester.pumpAndSettle();
      expect(find.byType(ActivityRow), findsNWidgets(2));

      controller.jumpTo(controller.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(find.byType(TurnFoldLine), findsNothing);
      expect(find.byType(ActivityRow), findsNothing);

      controller.jumpTo(0);
      await tester.pumpAndSettle();
      expect(_fold(tester).unfolded, isTrue);
      expect(find.byType(ActivityRow), findsNWidgets(2));
    });

    testWidgets('the final answer is in view after the automatic fold', (
      tester,
    ) async {
      final remote = await _startRemoteTurn(
        tester,
        'auto-fold',
        client: _ControlledChatHttpClient([
          for (var index = 0; index < 24; index++)
            {
              'role': index.isEven ? 'user' : 'assistant',
              'content':
                  'message $index\n${List.filled(5, 'filler').join('\n')}',
            },
        ]),
      );
      for (var call = 0; call < 12; call++) {
        remote.emit('tool.start', _terminal('call-$call'));
        remote.emit('tool.complete', _terminal('call-$call'));
      }
      remote.emit('message.delta', {'text': 'Interim note'});
      remote.emit('tool.start', _readFile('call-last'));
      remote.emit('tool.complete', _readFile('call-last'));
      remote.emit('message.delta', {'text': 'The final answer'});
      await _frames(tester);
      expect(find.byType(ActivityRow), findsWidgets);

      remote.emit('message.complete', {'text': 'The final answer'});
      remote.finish();
      await tester.pumpAndSettle();

      expect(find.byType(ActivityRow), findsNothing);
      expect(find.byType(TurnFoldLine), findsOneWidget);
      final controller = _listController(tester);
      expect(controller.position.pixels, controller.position.maxScrollExtent);
      final answer = tester.getRect(_bubble('The final answer'));
      final viewport = tester.getRect(find.byType(ListView).first);
      expect(answer.top, greaterThanOrEqualTo(viewport.top));
      expect(answer.bottom, lessThanOrEqualTo(viewport.bottom));
    });

    testWidgets('a turn stopped before a final answer keeps its rows', (
      tester,
    ) async {
      final remote = await _startRemoteTurn(tester, 'interrupted');
      remote.emit('message.delta', {'text': 'Looking at it'});
      remote.emit('tool.start', _terminal('call-1'));
      remote.emit('tool.complete', _terminal('call-1'));
      remote.finish();
      await tester.pumpAndSettle();

      expect(find.byType(TurnFoldLine), findsNothing);
      expect(_order(tester), ['bot:Looking at it', 'row']);
    });
  });

  group('detail sheet', () {
    testWidgets('tapping a row opens the sheet; closing it leaves the draft '
        'and the scroll offset alone', (tester) async {
      await _pumpChat(
        tester,
        client: _ControlledChatHttpClient([
          for (var index = 0; index < 12; index++)
            {
              'id': 1 + index,
              'role': index.isEven ? 'user' : 'assistant',
              'content':
                  'message $index\n${List.filled(5, 'filler').join('\n')}',
            },
          {'id': 101, 'role': 'user', 'content': 'go'},
          {
            'id': 102,
            'role': 'assistant',
            'content': '',
            'tool_calls': [
              {
                'id': 'call-1',
                'function': {
                  'name': 'terminal',
                  'arguments': jsonEncode({'command': 'flutter test'}),
                },
              },
            ],
          },
          {
            'id': 103,
            'role': 'tool',
            'name': 'terminal',
            'tool_call_id': 'call-1',
            'content': 'All tests passed!',
          },
          {'id': 104, 'role': 'assistant', 'content': 'All done'},
        ]),
        id: 'sheet',
      );
      await tester.tap(find.byType(TurnFoldLine));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'an unsent draft');
      final controller = _listController(tester);
      controller.jumpTo(controller.position.maxScrollExtent - 40);
      await tester.pumpAndSettle();
      final offset = controller.position.pixels;

      await tester.tap(find.byType(ActivityRow));
      await tester.pumpAndSettle();
      final sheet = find.byType(ActivityDetailSheet);
      expect(sheet, findsOneWidget);
      expect(
        find.descendant(of: sheet, matching: find.text('Terminal')),
        findsOneWidget,
      );
      // Read from the stored tool call and result when the sheet opened.
      expect(find.text('flutter test'), findsOneWidget);
      expect(find.text('All tests passed!'), findsOneWidget);

      Navigator.of(tester.element(find.byType(ActivityDetailSheet))).pop();
      await tester.pumpAndSettle();
      expect(find.byType(ActivityDetailSheet), findsNothing);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'an unsent draft',
      );
      expect(controller.position.pixels, closeTo(offset, 0.01));
    });

    testWidgets('tapping a group row lists each call', (tester) async {
      await _pumpChat(
        tester,
        client: _ControlledChatHttpClient([
          {'id': 1, 'role': 'user', 'content': 'go'},
          {
            ..._storedTool(2, 'call-1', 'terminal'),
            'args': {'command': 'flutter analyze'},
          },
          {
            ..._storedTool(3, 'call-2', 'terminal'),
            'args': {'command': 'flutter test'},
          },
          {'id': 4, 'role': 'assistant', 'content': 'All done'},
        ]),
        id: 'group-sheet',
      );
      await tester.tap(find.byType(TurnFoldLine));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ran 2 commands'));
      await tester.pumpAndSettle();

      expect(find.text('Command executions'), findsOneWidget);
      expect(find.text('flutter analyze'), findsOneWidget);
      expect(find.text('flutter test'), findsOneWidget);
    });
  });

  group('message metadata setting (D9)', () {
    final history = [
      {'id': 1, 'role': 'user', 'content': 'go'},
      _storedTool(2, 'call-1', 'terminal'),
      {
        'id': 3,
        'role': 'assistant',
        'content': 'Halfway there',
        '_gateway_reasoning': 'Checking the binding',
      },
      _storedTool(4, 'call-2', 'read_file'),
      {'id': 5, 'role': 'assistant', 'content': 'All done'},
    ];

    /// Every row the list built, by kind, with what each one shows.
    List<String> items(WidgetTester tester) => [
      for (final element
          in find
              .descendant(
                of: find.byType(ListView).first,
                matching: find.byWidgetPredicate(
                  (widget) =>
                      widget is ActivityRow ||
                      widget is TurnFoldLine ||
                      widget is MessageBubble,
                ),
              )
              .evaluate())
        switch (element.widget) {
          final ActivityRow row => 'row:${row.activity?.name ?? row.label}',
          final TurnFoldLine fold => 'fold:${fold.unfolded}:${fold.stepCount}',
          final MessageBubble bubble => 'bubble:${bubble.content}',
          _ => '',
        },
    ];

    testWidgets('a finished turn has the same items with the setting on '
        'and off, and metadata shows only when on', (tester) async {
      // Tall enough that metadata lines do not push rows out of the viewport.
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(600, 2400);
      addTearDown(tester.view.reset);
      final byMode = <bool, List<List<String>>>{};
      for (final verbose in [false, true]) {
        SharedPreferences.setMockInitialValues({'verbose_mode': verbose});
        await tester.pumpWidget(const SizedBox.shrink());
        await _pumpChat(
          tester,
          client: _ControlledChatHttpClient(history),
          id: 'metadata-$verbose',
        );
        final folded = items(tester);
        expect(
          find.textContaining('role: assistant'),
          verbose ? findsWidgets : findsNothing,
        );

        await tester.tap(find.byType(TurnFoldLine));
        await tester.pumpAndSettle();
        byMode[verbose] = [folded, items(tester)];
      }

      expect(byMode[true], byMode[false]);
      expect(byMode[false]!.first, [
        'bubble:go',
        'fold:false:3',
        'bubble:All done',
      ]);
      expect(byMode[false]!.last, [
        'bubble:go',
        'fold:true:3',
        'row:terminal',
        'row:Checking the binding',
        'bubble:Halfway there',
        'row:read_file',
        'bubble:All done',
      ]);
    });
  });
}

Map<String, dynamic> _terminal(String id) => {
  'tool_id': id,
  'name': 'terminal',
  'args': {'command': 'flutter test'},
};

Map<String, dynamic> _readFile(String id) => {
  'tool_id': id,
  'name': 'read_file',
  'args': {'path': 'lib/main.dart'},
};

Map<String, dynamic> _storedTool(int id, String callId, String name) => {
  'id': id,
  'role': 'tool',
  'name': name,
  'tool_call_id': callId,
  'content': 'output of $callId',
};

Finder _bubble(String text) => find.text(text, findRichText: true);

ScrollController _listController(WidgetTester tester) =>
    tester.widget<ListView>(find.byType(ListView).first).controller!;

TurnFoldLine _fold(WidgetTester tester) =>
    tester.widget<TurnFoldLine>(find.byType(TurnFoldLine));

/// Two frames: one for the event's setState, one for the follow-scroll.
Future<void> _frames(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// The chat list's activity rows, fold lines and assistant bubbles from top
/// to bottom. User bubbles are left out.
List<String> _order(WidgetTester tester) {
  final entries = <(double, String)>[];
  void collect(Finder finder, String Function(Widget widget) label) {
    for (final element in finder.evaluate()) {
      final box = element.renderObject! as RenderBox;
      entries.add((box.localToGlobal(Offset.zero).dy, label(element.widget)));
    }
  }

  collect(find.byType(ActivityRow), (_) => 'row');
  collect(find.byType(TurnFoldLine), (_) => 'fold');
  collect(
    find.byWidgetPredicate(
      (widget) => widget is MessageBubble && !widget.isUser,
    ),
    (widget) => 'bot:${(widget as MessageBubble).content}',
  );
  entries.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final entry in entries) entry.$2];
}

Future<_ControlledRemotePrompt> _startRemoteTurn(
  WidgetTester tester,
  String id, {
  _ControlledChatHttpClient? client,
}) async {
  final remote = _ControlledRemotePrompt();
  await _pumpChat(
    tester,
    client: client ?? _ControlledChatHttpClient(const []),
    id: id,
    remoteSubmit: remote.submit,
  );
  await tester.enterText(find.byType(TextField), 'go');
  await tester.tap(find.byTooltip('Send'));
  await tester.pump();
  await remote.started.future;
  return remote;
}

Future<void> _pumpChat(
  WidgetTester tester, {
  required _ControlledChatHttpClient client,
  required String id,
  TestRemotePromptSubmit? remoteSubmit,
  TestDesktopConnectionHook? connectionHook,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: ChatScreen(
        connection: SavedConnection(
          id: id,
          label: 'Fixture',
          host: 'fixture.example',
          port: 8642,
          apiKey: 'synthetic-test-key',
        ),
        session: Session(
          id: id,
          title: 'Fixture chat',
          model: 'fixture-model',
          source: 'test',
          messageCount: client.serverMessages.length,
          isActive: true,
          preview: '',
          startedAt: 1,
        ),
        testApiClient: ApiClient(
          baseUrl: 'http://fixture.example',
          apiKey: 'synthetic-test-key',
          httpClient: client,
        ),
        testRemotePromptSubmit: remoteSubmit,
        testDesktopConnectionHook: connectionHook,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

class _ControlledRemotePrompt {
  final Completer<void> started = Completer<void>();
  Completer<void>? _completion;
  StreamCallback? _onEvent;

  Future<void> submit({
    required String sessionId,
    required String text,
    required StreamCallback onEvent,
    required void Function() onSent,
  }) async {
    onSent();
    _onEvent = onEvent;
    _completion = Completer<void>();
    if (!started.isCompleted) started.complete();
    await _completion!.future;
  }

  void emit(String type, Map<String, dynamic> data) {
    _onEvent!(StreamEvent(type: type, data: data));
  }

  void finish() => _completion!.complete();
}

class _ControlledChatHttpClient extends http.BaseClient {
  _ControlledChatHttpClient(List<Map<String, dynamic>> messages)
    : serverMessages = List<Map<String, dynamic>>.from(messages);

  List<Map<String, dynamic>> serverMessages;
  final Completer<void> postStarted = Completer<void>();
  StreamController<List<int>>? _completionStream;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (request.method == 'GET' && request.url.path.endsWith('/messages')) {
      return _json({'data': serverMessages});
    }
    if (request.method == 'POST' &&
        request.url.path.endsWith('/v1/chat/completions')) {
      _completionStream = StreamController<List<int>>();
      if (!postStarted.isCompleted) postStarted.complete();
      return http.StreamedResponse(
        _completionStream!.stream,
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    }
    return _json({'error': 'unexpected request'}, statusCode: 404);
  }

  void emitToken(String token) => _completionStream!.add(
    utf8.encode(
      'data: ${jsonEncode({
        'choices': [
          {
            'delta': {'content': token},
          },
        ],
      })}\n\n',
    ),
  );

  void emitToolProgress(Map<String, dynamic> progress) =>
      _completionStream!.add(
        utf8.encode(
          'event: hermes.tool.progress\ndata: ${jsonEncode(progress)}\n\n',
        ),
      );

  void finish(List<Map<String, dynamic>> finalMessages) {
    serverMessages = List<Map<String, dynamic>>.from(finalMessages);
    _completionStream!
      ..add(utf8.encode('data: [DONE]\n\n'))
      ..close();
  }

  http.StreamedResponse _json(Object body, {int statusCode = 200}) =>
      http.StreamedResponse(
        Stream.value(utf8.encode(jsonEncode(body))),
        statusCode,
        headers: {'content-type': 'application/json'},
      );
}
