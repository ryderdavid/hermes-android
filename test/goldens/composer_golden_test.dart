import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/composer_harness.dart';
import 'golden_harness.dart';

void main() {
  final states = <String, ComposerHost Function()>{
    'idle': ComposerHost.new,
    'typing': () => ComposerHost(text: 'Summarise the build log'),
    'multiline': () => ComposerHost(
      text: List.generate(
        4,
        (i) => 'Step ${i + 1}: check the deploy',
      ).join('\n'),
    ),
    'streaming': () => ComposerHost(text: '')..streaming = true,
    'attachments': () => ComposerHost(
      text: 'What changed between these?',
      attachments: [ComposerHost.photo(0), ComposerHost.photo(1)],
    ),
  };

  for (final variant in goldenMatrix) {
    for (final entry in states.entries) {
      testWidgets('composer ${entry.key} ${variant.name}', (tester) async {
        await pumpGolden(
          tester,
          ComposerScaffold(host: entry.value()),
          variant: variant,
          size: const Size(412, 420),
          settle: entry.key != 'streaming',
        );
        await matchGolden(tester, 'composer/${entry.key}_${variant.name}.png');
      });
    }
  }
}
