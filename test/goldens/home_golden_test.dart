import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/session.dart';
import 'package:hermes_android/core/widgets/home_pane.dart';

import 'golden_harness.dart';

final _now = DateTime.utc(2026, 10, 29, 12);

Session _session(String id, String title, Duration ago, {bool active = false}) {
  final at = _now.subtract(ago).millisecondsSinceEpoch / 1000;
  return Session(
    id: id,
    title: title,
    model: 'gpt-oss-20b',
    source: 'gateway',
    messageCount: 6,
    isActive: active,
    preview: '',
    startedAt: at - 600,
    lastActive: at,
    endedAt: active ? null : at,
  );
}

final _sessions = [
  _session(
    'backup',
    'Nightly backup',
    const Duration(minutes: 2),
    active: true,
  ),
  _session(
    'print',
    'Print queue stuck',
    const Duration(minutes: 9),
    active: true,
  ),
  _session(
    'media',
    'Index the media library',
    const Duration(minutes: 1),
    active: true,
  ),
  _session('garden', 'Irrigation schedule', const Duration(hours: 1)),
  _session('budget', 'Quarterly budget note', const Duration(hours: 3)),
];

void main() {
  for (final variant in goldenMatrix) {
    testWidgets('home populated ${variant.name}', (tester) async {
      await pumpGolden(
        tester,
        Scaffold(
          body: HomePane(
            loadSessions: () async => _sessions,
            clock: () => _now,
            attention: const {
              'backup': 'Approve the prune command',
              'print': 'Hermes asked which printer to reset',
            },
            running: const {'media'},
            projectNames: const {
              'backup': 'Home lab',
              'media': 'Home lab',
              'garden': 'Garden',
            },
          ),
        ),
        variant: variant,
      );
      await matchGolden(tester, 'screens/home_populated_${variant.name}.png');
    });
  }
}
