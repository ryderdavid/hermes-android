import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/gateway_activity.dart';
import 'package:hermes_android/core/theme/hermes_theme.dart';
import 'package:hermes_android/core/widgets/activity_row.dart';

import 'support/l10n_test_utils.dart';

GatewayToolActivity _tool(
  String name,
  GatewayToolActivityPhase phase, {
  String? summary,
}) => GatewayToolActivity(name: name, phase: phase, summary: summary);

Future<void> _pump(WidgetTester tester, List<Widget> rows) async {
  await tester.pumpWidget(
    testAppWithL10n(Scaffold(body: ListView(children: rows))),
  );
  // A running row spins, so it never settles.
  await tester.pump(const Duration(milliseconds: 300));
}

Text _label(WidgetTester tester) => tester.widget<Text>(
  find.descendant(of: find.byType(ActivityRow), matching: find.byType(Text)),
);

void main() {
  testWidgets('a running call shows a progress indicator and normal text', (
    tester,
  ) async {
    await _pump(tester, [
      ActivityRow.tool(
        activity: _tool(
          'terminal',
          GatewayToolActivityPhase.running,
          summary: 'running the test suite',
        ),
      ),
    ]);

    expect(find.text('Running the test suite'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.byIcon(Icons.terminal), findsNothing);
    final context = tester.element(find.byType(ActivityRow));
    expect(
      _label(tester).style!.color,
      Theme.of(context).colorScheme.onSurface,
    );
  });

  for (final phase in [
    GatewayToolActivityPhase.generating,
    GatewayToolActivityPhase.progress,
  ]) {
    testWidgets('a ${phase.name} call counts as running', (tester) async {
      await _pump(tester, [
        ActivityRow.tool(activity: _tool('terminal', phase)),
      ]);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  }

  testWidgets('a completed call is muted and shows its kind icon', (
    tester,
  ) async {
    await _pump(tester, [
      ActivityRow.tool(
        activity: _tool(
          'read_file',
          GatewayToolActivityPhase.completed,
          summary: 'lib/core/theme/hermes_theme.dart',
        ),
      ),
    ]);

    expect(
      find.text('Read file: lib/core/theme/hermes_theme.dart'),
      findsOneWidget,
    );
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.byIcon(Icons.description_outlined), findsOneWidget);
    final context = tester.element(find.byType(ActivityRow));
    expect(_label(tester).style!.color, HermesTokens.of(context).muted);
  });

  testWidgets('a failed call uses the error colour and says it failed', (
    tester,
  ) async {
    await _pump(tester, [
      ActivityRow.tool(
        activity: _tool(
          'terminal',
          GatewayToolActivityPhase.failed,
          summary: 'checking the current window state',
        ),
      ),
    ]);

    expect(
      find.text('Failed: Checking the current window state'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    final context = tester.element(find.byType(ActivityRow));
    final danger = HermesTokens.of(context).danger;
    expect(_label(tester).style!.color, danger);
    expect(tester.widget<Icon>(find.byIcon(Icons.error_outline)).color, danger);
  });

  testWidgets('a call without a summary keeps the bare tool name', (
    tester,
  ) async {
    await _pump(tester, [
      ActivityRow.tool(
        activity: _tool('skills_list', GatewayToolActivityPhase.completed),
      ),
    ]);
    expect(find.text('Skills list'), findsOneWidget);
  });

  testWidgets('a long summary stays on one line', (tester) async {
    await _pump(tester, [
      ActivityRow.tool(
        activity: _tool(
          'terminal',
          GatewayToolActivityPhase.completed,
          summary: 'looking for a very long thing ' * 12,
        ),
      ),
    ]);
    final label = _label(tester);
    expect(label.maxLines, 1);
    expect(label.overflow, TextOverflow.ellipsis);
    expect(
      tester.getSize(find.byType(ActivityRow)).height,
      ActivityRow.minHeight,
    );
  });

  testWidgets('every state is the same 48dp row, so a state change moves '
      'nothing', (tester) async {
    await _pump(tester, [
      for (final phase in GatewayToolActivityPhase.values)
        ActivityRow.tool(activity: _tool('terminal', phase)),
      const ActivityRow.reasoning(headline: 'Checking the service binding'),
      ActivityRow.group(
        first: _tool('terminal', GatewayToolActivityPhase.completed),
        count: 3,
      ),
    ]);
    for (final element in find.byType(ActivityRow).evaluate()) {
      expect(element.size!.height, 48);
      expect(element.size!.width, 800);
    }
    // No card around a row.
    expect(find.byType(Card), findsNothing);
  });

  testWidgets('reasoning shows its headline, or Thinking without one', (
    tester,
  ) async {
    await _pump(tester, const [
      ActivityRow.reasoning(headline: 'Checking the service binding'),
      ActivityRow.reasoning(),
      ActivityRow.reasoning(running: true),
    ]);
    expect(find.text('Checking the service binding'), findsOneWidget);
    expect(find.text('Thinking'), findsNWidgets(2));
    expect(find.byIcon(Icons.psychology_outlined), findsNWidgets(2));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('a group row states the kind and the count', (tester) async {
    await _pump(tester, [
      ActivityRow.group(
        first: _tool('terminal', GatewayToolActivityPhase.completed),
        count: 3,
      ),
      ActivityRow.group(
        first: _tool('read_file', GatewayToolActivityPhase.completed),
        count: 2,
      ),
      ActivityRow.group(
        first: _tool('patch', GatewayToolActivityPhase.completed),
        count: 2,
      ),
      ActivityRow.group(
        first: _tool('web_search', GatewayToolActivityPhase.completed),
        count: 4,
      ),
      ActivityRow.group(
        first: _tool('skill_view', GatewayToolActivityPhase.completed),
        count: 2,
      ),
    ]);
    expect(find.text('Ran 3 commands'), findsOneWidget);
    expect(find.text('Read 2 files'), findsOneWidget);
    expect(find.text('Edited 2 files'), findsOneWidget);
    expect(find.text('Ran 4 searches'), findsOneWidget);
    expect(find.text('Used Skill view 2 times'), findsOneWidget);
  });

  testWidgets('tapping a row calls onTap', (tester) async {
    var taps = 0;
    await _pump(tester, [
      ActivityRow.tool(
        activity: _tool('terminal', GatewayToolActivityPhase.completed),
        onTap: () => taps++,
      ),
    ]);
    await tester.tap(find.byType(ActivityRow));
    expect(taps, 1);
  });

  group('semantics', () {
    Future<SemanticsNode> node(WidgetTester tester, Widget row) async {
      await _pump(tester, [row]);
      return tester.getSemantics(find.byType(ActivityRow));
    }

    testWidgets('a running call announces kind, summary and state', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final semantics = await node(
        tester,
        ActivityRow.tool(
          activity: _tool(
            'terminal',
            GatewayToolActivityPhase.running,
            summary: 'running the test suite',
          ),
          onTap: () {},
        ),
      );
      expect(semantics.label, 'Terminal, Running the test suite, Running');
      expect(
        semantics,
        matchesSemantics(
          label: 'Terminal, Running the test suite, Running',
          isButton: true,
          hasTapAction: true,
          onTapHint: 'Show details',
        ),
      );
      handle.dispose();
    });

    testWidgets('a completed call says completed', (tester) async {
      final handle = tester.ensureSemantics();
      final semantics = await node(
        tester,
        ActivityRow.tool(
          activity: _tool(
            'read_file',
            GatewayToolActivityPhase.completed,
            summary: 'lib/main.dart',
          ),
          onTap: () {},
        ),
      );
      expect(semantics.label, 'Read file, Read file: lib/main.dart, Completed');
      handle.dispose();
    });

    testWidgets('a failed call says failed', (tester) async {
      final handle = tester.ensureSemantics();
      final semantics = await node(
        tester,
        ActivityRow.tool(
          activity: _tool(
            'terminal',
            GatewayToolActivityPhase.failed,
            summary: 'running the test suite',
          ),
          onTap: () {},
        ),
      );
      expect(semantics.label, 'Terminal, Running the test suite, Failed');
      handle.dispose();
    });

    testWidgets('reasoning and group rows are labelled too', (tester) async {
      final handle = tester.ensureSemantics();
      final reasoning = await node(
        tester,
        ActivityRow.reasoning(
          headline: 'Checking the service binding',
          onTap: () {},
        ),
      );
      expect(
        reasoning.label,
        'Reasoning, Checking the service binding, Completed',
      );
      final group = await node(
        tester,
        ActivityRow.group(
          first: _tool('terminal', GatewayToolActivityPhase.completed),
          count: 3,
          onTap: () {},
        ),
      );
      expect(group.label, 'Terminal, Ran 3 commands, Completed');
      handle.dispose();
    });
  });
}
