import 'package:flutter/material.dart';

import '../theme/hermes_theme.dart';

/// A Pixel-style Settings section: a [title] in the primary color above its
/// rows, each row on a tonal `surfaceContainer` tile separated by a 2dp gap.
///
/// The outer corners of the group are 24dp and the inner corners 4dp, so the
/// rows read as one rounded block, like Android 16's Settings.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({this.title, required this.children, super.key});

  final String? title;
  final List<Widget> children;

  static const double outerRadius = HermesRadius.xl;
  static const double innerRadius = 4;
  static const double gap = 2;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final rows = [
      for (final child in children)
        if (child is! SizedBox || child.child != null) child,
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: HermesSpacing.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                HermesSpacing.lg,
                0,
                HermesSpacing.lg,
                HermesSpacing.sm,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  title!,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ),
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const SizedBox(height: gap),
            _SettingsTile(
              borderRadius: BorderRadius.vertical(
                top: Radius.circular(i == 0 ? outerRadius : innerRadius),
                bottom: Radius.circular(
                  i == rows.length - 1 ? outerRadius : innerRadius,
                ),
              ),
              child: rows[i],
            ),
          ],
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.borderRadius, required this.child});

  final BorderRadius borderRadius;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Cards inside a group become part of the tile rather than a second
    // container: same color, no margin, the tile's corners.
    return Material(
      color: theme.colorScheme.surfaceContainer,
      borderRadius: borderRadius,
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(
          cardTheme: theme.cardTheme.copyWith(
            color: theme.colorScheme.surfaceContainer,
            margin: EdgeInsets.zero,
            shape: const RoundedRectangleBorder(),
          ),
        ),
        child: child,
      ),
    );
  }
}
