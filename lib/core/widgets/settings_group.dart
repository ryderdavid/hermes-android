import 'package:flutter/material.dart';

import '../expressive/segmented_list.dart';
import '../theme/hermes_theme.dart';

/// A Pixel-style Settings section: a [SegmentedListGroup] whose rows may be
/// arbitrary widgets (cards, switches, pickers), each set on a segmented
/// tile so the section reads as one rounded block, like Android 16 Settings.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({this.title, required this.children, super.key});

  final String? title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final rows = [
      for (final child in children)
        if (child is! SizedBox || child.child != null) child,
    ];
    return SegmentedListGroup(
      title: title,
      padding: const EdgeInsets.only(bottom: HermesSpacing.xl),
      children: [for (final row in rows) _SettingsTile(child: row)],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final radius =
        (SegmentScope.maybeOf(context) ?? SegmentPosition.only).radius();
    final fill = theme.colorScheme.surfaceContainerLow;
    // Cards inside a group become part of the tile rather than a second
    // container: same color, no margin, the tile's corners.
    return Material(
      color: fill,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: Theme(
        data: theme.copyWith(
          cardTheme: theme.cardTheme.copyWith(
            color: fill,
            margin: EdgeInsets.zero,
            shape: const RoundedRectangleBorder(),
          ),
        ),
        child: child,
      ),
    );
  }
}
