import 'dart:ui' show Tristate;
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/theme/hermes_theme.dart';
import 'package:hermes_android/l10n/app_localizations.dart';

import 'support/composer_harness.dart';

Future<ComposerScaffoldState> _pump(
  WidgetTester tester,
  ComposerHost host,
) async {
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: hermesTheme(Brightness.light),
      home: ComposerScaffold(host: host),
    ),
  );
  await tester.pump();
  return tester.state<ComposerScaffoldState>(find.byType(ComposerScaffold));
}

Finder get _field => find.byKey(const Key('chat-composer-field'));
Finder get _send => find.byTooltip('Send');

IconButton _sendButton(WidgetTester tester) =>
    tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.send));

/// The send button renders with the theme's primary only when it can act.
Color? _sendBackground(WidgetTester tester) {
  final material = tester.widget<Material>(
    find
        .descendant(
          of: find.widgetWithIcon(IconButton, Icons.send),
          matching: find.byType(Material),
        )
        .first,
  );
  return material.color;
}

void main() {
  testWidgets('attach sits outside the field; the field owns the mic', (
    tester,
  ) async {
    await _pump(tester, ComposerHost());
    final field = tester.getRect(_field);
    final decoration =
        tester.widget<Container>(_field).decoration! as BoxDecoration;
    final scheme = Theme.of(tester.element(_field)).colorScheme;

    expect(field.height, 48);
    expect(decoration.color, scheme.surfaceContainerHigh);
    expect(decoration.border, isNull);
    expect(decoration.borderRadius, BorderRadius.circular(24));

    final mic = tester.getRect(find.byTooltip('Speak to Hermes'));
    expect(field.contains(mic.center), isTrue);

    final attach = tester.getRect(find.byTooltip('Attach image or file'));
    expect(field.contains(attach.center), isFalse);
    expect(attach.right, lessThan(field.left));
    expect(attach.size, const Size(48, 48));
    expect(attach.bottom, field.bottom);

    final send = tester.getRect(_send);
    expect(field.contains(send.center), isFalse);
    expect(send.left, greaterThan(field.right));
    expect(send.height, lessThanOrEqualTo(48));
    expect(send.height, lessThanOrEqualTo(field.height));
    expect(send.bottom, field.bottom);
  });

  testWidgets(
    'the field grows with a long draft and send stays at the bottom',
    (tester) async {
      final host = ComposerHost(
        text: List.generate(4, (i) => 'Line ${i + 1}').join('\n'),
      );
      await _pump(tester, host);

      final field = tester.getRect(_field);
      expect(field.height, greaterThan(48));
      expect(tester.getRect(_send).bottom, field.bottom);
      expect(tester.getRect(_send).height, 48);
    },
  );

  testWidgets('send goes empty → typing → streaming → stopped', (tester) async {
    final host = ComposerHost();
    final state = await _pump(tester, host);
    final scheme = Theme.of(tester.element(_field)).colorScheme;

    // Empty: disabled-styled (sending an empty draft is a no-op upstream).
    expect(_sendBackground(tester), isNot(scheme.primary));

    // Typing: an enabled primary Send.
    await tester.enterText(
      find.byKey(const Key('chat-message-composer')),
      'Hi',
    );
    await tester.pump();
    expect(_sendBackground(tester), scheme.primary);
    await tester.tap(_send);
    expect(host.sends, 1);

    // Streaming: the same slot shows Stop, and Stop stops.
    state.update(() => host.streaming = true);
    await tester.pump();
    expect(find.byTooltip('Stop response'), findsOneWidget);
    expect(_send, findsNothing);
    await tester.tap(find.byTooltip('Stop response'));
    expect(host.stops, 1);

    // Stopped: back to Send with the draft intact.
    state.update(() => host.streaming = false);
    await tester.pump();
    expect(_sendButton(tester).onPressed, isNotNull);
    expect(host.textController.text, 'Hi');
  });

  testWidgets('attachments alone make send look enabled', (tester) async {
    await _pump(tester, ComposerHost(attachments: [ComposerHost.photo(0)]));
    final scheme = Theme.of(tester.element(_field)).colorScheme;

    expect(_sendBackground(tester), scheme.primary);
    expect(find.bySemanticsLabel('Attachment drafts'), findsOneWidget);
  });

  testWidgets('the composer holds only attach, the field and send', (
    tester,
  ) async {
    await _pump(tester, ComposerHost());

    // Model and spoken replies moved to the chat app bar and overflow menu.
    expect(find.byKey(const Key('chat-model-chip')), findsNothing);
    expect(find.byKey(const Key('chat-spoken-replies-chip')), findsNothing);
    expect(find.byType(IconButton), findsNWidgets(3));
  });

  testWidgets('Stop springs to a rounded square; Send is round', (
    tester,
  ) async {
    final host = ComposerHost(text: 'Hi');
    final state = await _pump(tester, host);
    double radius(IconData icon) {
      final button = tester.widget<IconButton>(
        find.widgetWithIcon(IconButton, icon),
      );
      final shape =
          button.style!.shape!.resolve(<WidgetState>{})!
              as RoundedRectangleBorder;
      return (shape.borderRadius as BorderRadius).topLeft.x;
    }

    expect(radius(Icons.send), 24);
    state.update(() => host.streaming = true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(radius(Icons.stop_rounded), closeTo(14, 0.5));
  });

  testWidgets('keeps upstream field behaviour: Enter is a newline', (
    tester,
  ) async {
    await _pump(tester, ComposerHost());
    final field = tester.widget<TextField>(
      find.byKey(const Key('chat-message-composer')),
    );

    expect(field.textInputAction, TextInputAction.newline);
    expect(field.keyboardType, TextInputType.multiline);
    expect(field.minLines, 1);
    expect(field.maxLines, 5);
    expect(field.textCapitalization, TextCapitalization.sentences);
  });

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets('one-line text is vertically centred in the field at $scale', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: hermesTheme(Brightness.light),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: ComposerScaffold(host: ComposerHost()),
        ),
      );
      await tester.pump();

      final field = tester.getRect(_field);
      final text = tester.getRect(find.byType(EditableText));
      expect(text.center.dy, moreOrLessEquals(field.center.dy, epsilon: 0.5));
    });
  }

  /// Accessibility services (TalkBack, voice keyboards pressing Send via
  /// ACTION_CLICK) see a merged semantics node for the send/stop button. The
  /// merge must keep the tap action: a button node with no tap action is
  /// reported to Android as a non-clickable button and cannot be pressed.
  testWidgets('send button stays a tappable button to accessibility services', (
    tester,
  ) async {
    final host = ComposerHost(text: 'hello');
    await _pump(tester, host);
    // Keep the semantics tree alive after getSemantics, or performAction
    // (below) dispatches into a disposed tree.
    final semantics = tester.ensureSemantics();

    final node = tester.getSemantics(
      find.widgetWithIcon(IconButton, Icons.send),
    );
    final data = node.getSemanticsData();
    expect(data.label, 'Send message');
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.flagsCollection.isEnabled, Tristate.isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);

    // What a voice keyboard's ACTION_CLICK does.
    node.owner?.performAction(node.id, SemanticsAction.tap);
    await tester.pump();
    expect(host.sends, 1);
    semantics.dispose();
  });

  testWidgets('stop button stays a tappable button while streaming', (
    tester,
  ) async {
    final host = ComposerHost()..streaming = true;
    await _pump(tester, host);
    final semantics = tester.ensureSemantics();

    final node = tester.getSemantics(
      find.widgetWithIcon(IconButton, Icons.stop_rounded),
    );
    final data = node.getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.flagsCollection.isEnabled, Tristate.isTrue);
    expect(data.hasAction(SemanticsAction.tap), isTrue);

    node.owner?.performAction(node.id, SemanticsAction.tap);
    await tester.pump();
    expect(host.stops, 1);
    semantics.dispose();
  });
}
