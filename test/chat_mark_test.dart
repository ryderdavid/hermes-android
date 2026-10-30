import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/chat_icons/chat_icon_labeller.dart';
import 'package:hermes_android/core/chat_icons/chat_icon_settings.dart';
import 'package:hermes_android/core/chat_icons/chat_icon_settings_section.dart';
import 'package:hermes_android/core/chat_icons/chat_icon_store.dart';
import 'package:hermes_android/core/chat_icons/chat_mark.dart';
import 'package:hermes_android/core/expressive/expressive.dart';
import 'package:hermes_android/core/theme/hermes_theme.dart';
import 'package:hermes_android/l10n/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

Widget _app(Widget child) => MaterialApp(
  theme: hermesTheme(Brightness.light),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: ListView(children: [child])),
);

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    ChatIconStore.resetCache();
  });

  tearDown(() => chatIconSelection.value = const ChatIconSettings());

  ShapeMark mark(WidgetTester tester) =>
      tester.widget<ShapeMark>(find.byType(ShapeMark));

  const garden = 'Fix the leaking garden hose';

  testWidgets('Letter mode keeps the letter mark it was given', (tester) async {
    await tester.pumpWidget(
      _app(
        const ChatMark(
          sessionId: 's1',
          title: garden,
          letterStyle: MarkStyle.unassigned,
        ),
      ),
    );
    expect(mark(tester).style, MarkStyle.unassigned);
    expect(mark(tester).icon, isNull);
    expect(mark(tester).label, garden);
  });

  testWidgets('On device shows the matched icon in the chat\'s own shape', (
    tester,
  ) async {
    chatIconSelection.value = const ChatIconSettings(
      mode: ChatIconMode.onDevice,
    );
    await tester.pumpWidget(
      _app(
        const ChatMark(
          sessionId: 's1',
          title: garden,
          letterStyle: MarkStyle.unassigned,
        ),
      ),
    );
    expect(mark(tester).icon, Icons.water_drop_rounded);
    expect(mark(tester).style, chatMarkStyle('s1'));

    chatIconSelection.value = const ChatIconSettings(
      mode: ChatIconMode.onDevice,
      mixedShapes: false,
    );
    await tester.pump();
    expect(mark(tester).style.shape, ExpressiveShape.cookie);
  });

  test('chat shapes vary across chats but not for one chat', () {
    final shapes = {
      for (var i = 0; i < 40; i++) chatMarkStyle('session-$i').shape,
    };
    expect(shapes.length, greaterThan(5));
    expect(chatMarkStyle('abc'), chatMarkStyle('abc'));
  });

  testWidgets('By Hermes asks for a label, then shows it', (tester) async {
    chatIconSelection.value = const ChatIconSettings(mode: ChatIconMode.hermes);
    final store = ChatIconStore.forConnection(prefs, 'home');
    final answer = Completer<String>();
    final asked = <String>[];
    final labeller = ChatIconLabeller(
      store: store,
      debounce: const Duration(milliseconds: 10),
      complete: ({required sessionId, required system, required user}) {
        asked.add(user);
        return answer.future;
      },
    );
    addTearDown(labeller.dispose);

    await tester.pumpWidget(
      _app(
        ChatIconScope(
          store: store,
          labeller: labeller,
          child: const ChatMark(
            sessionId: 's1',
            title: garden,
            letterStyle: MarkStyle.unassigned,
          ),
        ),
      ),
    );
    // The on-device match shows while Hermes is asked.
    expect(mark(tester).icon, Icons.water_drop_rounded);
    await tester.pump(const Duration(milliseconds: 20));
    expect(asked, hasLength(1));
    expect(asked.single, contains(garden));

    answer.complete('{"s1":"yard"}');
    await tester.pumpAndSettle();
    expect(mark(tester).icon, Icons.yard_rounded);
  });

  testWidgets('a pinned chat keeps its pin as a badge on a topic mark', (
    tester,
  ) async {
    chatIconSelection.value = const ChatIconSettings(
      mode: ChatIconMode.onDevice,
    );
    await tester.pumpWidget(
      _app(
        const ChatMark(
          sessionId: 's1',
          title: garden,
          letterStyle: MarkStyle.unassigned,
          letterIcon: Icons.push_pin,
          badge: Icons.push_pin,
        ),
      ),
    );
    expect(find.byIcon(Icons.push_pin), findsOneWidget);
    expect(find.byIcon(Icons.water_drop_rounded), findsOneWidget);
  });

  group('Appearance › Chat icons', () {
    testWidgets('switching modes persists and shows the Hermes rows', (
      tester,
    ) async {
      await tester.pumpWidget(
        _app(
          ChatIconSettingsSection(
            preferences: prefs,
            connectionId: 'home',
            connectionLabel: 'Miniserver',
          ),
        ),
      );
      expect(find.text('Chat icons'), findsOneWidget);
      expect(find.byKey(const Key('chat-icons-relabel')), findsNothing);
      expect(find.byKey(const Key('chat-icons-mixed-shapes')), findsNothing);

      await tester.tap(find.byKey(const Key('chat-icons-hermes')));
      await tester.pumpAndSettle();
      expect(prefs.getString(ChatIconPreferences.modeKey), 'hermes');
      expect(chatIconSelection.value.mode, ChatIconMode.hermes);
      expect(find.byKey(const Key('chat-icons-relabel')), findsOneWidget);
      expect(find.textContaining('Miniserver'), findsOneWidget);
      expect(find.text('0 labelled by Hermes · 0 waiting'), findsOneWidget);

      await tester.tap(find.byKey(const Key('chat-icons-mixed-shapes')));
      await tester.pumpAndSettle();
      expect(prefs.getBool(ChatIconPreferences.mixedShapesKey), isFalse);

      await tester.tap(find.byKey(const Key('chat-icons-on-device')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('chat-icons-relabel')), findsNothing);
      expect(ChatIconPreferences(prefs).read().mode, ChatIconMode.onDevice);
    });

    testWidgets('Relabel all chats clears Hermes\'s labels', (tester) async {
      chatIconSelection.value = const ChatIconSettings(
        mode: ChatIconMode.hermes,
      );
      final store = ChatIconStore.forConnection(prefs, 'home');
      await store.putAll({'s1': (icon: 'yard', title: garden)});
      await tester.pumpWidget(
        _app(ChatIconSettingsSection(preferences: prefs, connectionId: 'home')),
      );
      expect(find.text('1 labelled by Hermes · 0 waiting'), findsOneWidget);
      await tester.tap(find.byKey(const Key('chat-icons-relabel')));
      await tester.pumpAndSettle();
      expect(store.topicFor('s1', garden), isNull);
      expect(find.text('0 labelled by Hermes · 0 waiting'), findsOneWidget);
    });
  });
}
