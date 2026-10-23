import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'golden_harness.dart';

/// A scaffold with the surfaces pure black must keep apart: background,
/// a card, a filled field and a sheet-coloured container.
class _SurfaceSampler extends StatelessWidget {
  const _SurfaceSampler();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Surfaces')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Card(
            child: ListTile(
              leading: Icon(Icons.palette_outlined),
              title: Text('Card on background'),
              subtitle: Text('surfaceContainer'),
            ),
          ),
          const SizedBox(height: 16),
          const TextField(
            decoration: InputDecoration(
              filled: true,
              hintText: 'Filled text field',
            ),
          ),
          const SizedBox(height: 16),
          Container(
            height: 96,
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            alignment: Alignment.center,
            child: const Text('Bottom sheet surface'),
          ),
        ],
      ),
    );
  }
}

void main() {
  for (final variant in goldenMatrix.where(
    (v) => v.brightness == Brightness.dark,
  )) {
    testWidgets('surfaces ${variant.name}', (tester) async {
      await pumpGolden(
        tester,
        const _SurfaceSampler(),
        variant: variant,
        size: const Size(412, 420),
      );
      await matchGolden(tester, 'pure_black/surfaces_${variant.name}.png');
    });
  }
}
