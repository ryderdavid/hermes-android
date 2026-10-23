import 'package:flutter/material.dart';
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
  testWidgets('one rounded field owns attach and mic; send sits outside', (
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
    for (final inside in ['Attach image or file', 'Speak to Hermes']) {
      final rect = tester.getRect(find.byTooltip(inside));
      expect(field.contains(rect.center), isTrue, reason: inside);
    }
    final attach = tester.getRect(find.byTooltip('Attach image or file'));
    final mic = tester.getRect(find.byTooltip('Speak to Hermes'));
    expect(attach.left, lessThan(mic.left));

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

  testWidgets('model and spoken replies are compact chips above the field', (
    tester,
  ) async {
    final host = ComposerHost();
    final state = await _pump(tester, host);
    final model = find.byKey(const Key('chat-model-chip'));
    final spoken = find.byKey(const Key('chat-spoken-replies-chip'));
    final field = tester.getRect(_field);

    for (final chip in [model, spoken]) {
      expect(tester.getRect(chip).bottom, lessThanOrEqualTo(field.top));
    }
    // Only the send button sits in the input row beside the field.
    expect(find.byType(IconButton).evaluate().length, 3);

    await tester.tap(model);
    expect(host.modelPickerOpens, 1);

    expect(tester.widget<FilterChip>(spoken).selected, isTrue);
    await tester.tap(spoken);
    state.update(() {});
    await tester.pump();
    expect(host.voiceReplyEnabled, isFalse);
    expect(tester.widget<FilterChip>(spoken).selected, isFalse);

    // The choice survives unrelated rebuilds (typing, a turn starting).
    await tester.enterText(find.byKey(const Key('chat-message-composer')), 'x');
    state.update(() => host.streaming = true);
    await tester.pump();
    expect(tester.widget<FilterChip>(spoken).selected, isFalse);
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
}
