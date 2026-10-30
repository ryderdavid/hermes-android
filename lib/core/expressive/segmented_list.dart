import 'package:flutter/material.dart';

/// Where a row sits in a segmented group; decides its corners.
enum SegmentPosition {
  only,
  first,
  middle,
  last;

  static SegmentPosition of(int index, int count) {
    if (count <= 1) return only;
    if (index == 0) return first;
    if (index == count - 1) return last;
    return middle;
  }

  /// Outer corners [outer], inner corners [inner] (Material 3 Expressive
  /// segmented lists: 24 and 4).
  BorderRadius radius({double outer = 24, double inner = 4}) {
    final o = Radius.circular(outer);
    final i = Radius.circular(inner);
    return switch (this) {
      only => BorderRadius.all(o),
      first => BorderRadius.vertical(top: o, bottom: i),
      middle => BorderRadius.all(i),
      last => BorderRadius.vertical(top: i, bottom: o),
    };
  }
}

/// Tells a row inside a [SegmentedListGroup] where it sits, so rows built
/// elsewhere (cards, tiles) take the group's corners.
class SegmentScope extends InheritedWidget {
  const SegmentScope({required this.position, required super.child, super.key});

  final SegmentPosition position;

  static SegmentPosition? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SegmentScope>()?.position;

  @override
  bool updateShouldNotify(SegmentScope old) => old.position != position;
}

/// A Material 3 Expressive segmented list: rows separated by 2dp with 24dp
/// outer and 4dp inner corners, under an optional [title] in the primary
/// colour.
class SegmentedListGroup extends StatelessWidget {
  const SegmentedListGroup({
    required this.children,
    this.title,
    this.trailing,
    this.gap = 2,
    this.padding = EdgeInsets.zero,
    super.key,
  });

  final List<Widget> children;
  final String? title;

  /// Shown at the end of the title row (a "See all" button, a count).
  final Widget? trailing;
  final double gap;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null || trailing != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
              child: Row(
                children: [
                  if (title != null)
                    Expanded(
                      child: Semantics(
                        header: true,
                        child: Text(
                          title!,
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ?trailing,
                ],
              ),
            ),
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) SizedBox(height: gap),
            SegmentScope(
              position: SegmentPosition.of(i, children.length),
              child: children[i],
            ),
          ],
        ],
      ),
    );
  }
}

/// A row in a segmented list: optional [leading] (a tonal icon circle or a
/// shape mark), [title], [subtitle], [trailing], and a tap target that fills
/// the row.
class SegmentedTile extends StatelessWidget {
  const SegmentedTile({
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.color,
    this.minHeight = 72,
    this.titleMaxLines = 1,
    this.subtitleMaxLines = 1,
    this.emphasized = false,
    super.key,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;
  final double minHeight;
  final int titleMaxLines;
  final int subtitleMaxLines;

  /// Bolder title, for rows that need attention (unread, blocked).
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final radius = (SegmentScope.maybeOf(context) ?? SegmentPosition.only)
        .radius();
    return Material(
      color: color ?? scheme.surfaceContainerLow,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (leading != null) ...[leading!, const SizedBox(width: 16)],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: titleMaxLines,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: emphasized
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      if (subtitle != null && subtitle!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle!,
                          maxLines: subtitleMaxLines,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 12), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A 40dp circle in a container role holding an icon: the leading element of
/// settings rows.
class TonalIcon extends StatelessWidget {
  const TonalIcon(this.icon, {this.tone, this.size = 40, super.key});

  final IconData icon;

  /// `(container, onContainer)`; defaults to the primary container pair.
  final (Color, Color)? tone;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (fill, ink) =
        tone ?? (scheme.primaryContainer, scheme.onPrimaryContainer);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
        child: Icon(icon, size: size * 0.55, color: ink),
      ),
    );
  }
}
