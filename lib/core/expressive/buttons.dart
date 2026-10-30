import 'package:flutter/material.dart';

import 'springs.dart';

/// One choice in a [ConnectedButtonGroup].
@immutable
class ConnectedButton<T> {
  const ConnectedButton({
    required this.value,
    required this.label,
    this.icon,
    this.key,
  });

  final T value;
  final String label;
  final IconData? icon;
  final Key? key;
}

/// A Material 3 Expressive connected button group: single-select toggle
/// buttons 2dp apart. The selected button fills and springs to fully round;
/// the others keep small inner corners.
class ConnectedButtonGroup<T> extends StatelessWidget {
  const ConnectedButtonGroup({
    required this.buttons,
    required this.selected,
    required this.onSelected,
    this.height = 40,
    this.expand = false,
    this.semanticsLabel,
    super.key,
  });

  final List<ConnectedButton<T>> buttons;
  final T selected;
  final ValueChanged<T> onSelected;

  /// Visual height; the touch target is never less than 48dp.
  final double height;

  /// Share the full width equally instead of sizing to labels.
  final bool expand;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < buttons.length; i++) {
      if (i > 0) children.add(const SizedBox(width: 2));
      final button = ConnectedButtonView(
        key: buttons[i].key,
        label: buttons[i].label,
        icon: buttons[i].icon,
        selected: buttons[i].value == selected,
        first: i == 0,
        last: i == buttons.length - 1,
        height: height,
        onTap: () => onSelected(buttons[i].value),
      );
      children.add(expand ? Expanded(child: button) : button);
    }
    return Semantics(
      label: semanticsLabel,
      container: semanticsLabel != null,
      child: Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        children: children,
      ),
    );
  }
}

/// One button of a [ConnectedButtonGroup]; public so tests can read
/// [selected].
class ConnectedButtonView extends StatelessWidget {
  const ConnectedButtonView({
    required this.label,
    required this.selected,
    required this.first,
    required this.last,
    required this.height,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String label;
  final IconData? icon;
  final bool selected;
  final bool first;
  final bool last;
  final double height;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final full = Radius.circular(height / 2);
    const inner = Radius.circular(8);
    final radius = selected
        ? BorderRadius.all(full)
        : BorderRadius.horizontal(
            left: first ? full : inner,
            right: last ? full : inner,
          );
    final fg = selected ? scheme.onSecondary : scheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: height < 48 ? 48 : height,
          child: Center(
            child: AnimatedContainer(
              duration: HermesSprings.shapeDuration,
              curve: HermesSprings.shape,
              height: height,
              padding: EdgeInsets.symmetric(horizontal: selected ? 18 : 16),
              decoration: BoxDecoration(
                color: selected
                    ? scheme.secondary
                    : scheme.surfaceContainerHighest,
                borderRadius: radius,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (selected || icon != null) ...[
                    Icon(selected ? Icons.check : icon, size: 18, color: fg),
                    const SizedBox(width: 6),
                  ],
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: fg,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One entry in a [SplitButton]'s menu.
@immutable
class SplitButtonItem {
  const SplitButtonItem({
    required this.label,
    required this.onPressed,
    this.key,
    this.destructive = false,
    this.subtitle,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Key? key;
  final bool destructive;

  /// A second line saying what the choice does.
  final String? subtitle;
  final IconData? icon;
}

/// A Material 3 Expressive split button: a filled primary action joined to a
/// menu button holding the alternatives.
class SplitButton extends StatelessWidget {
  const SplitButton({
    required this.label,
    required this.onPressed,
    required this.items,
    this.primaryKey,
    this.menuTooltip,
    this.height = 56,
    this.child,
    this.menuKey,
    super.key,
  });

  final String label;
  final VoidCallback? onPressed;
  final List<SplitButtonItem> items;
  final Key? primaryKey;
  final String? menuTooltip;
  final double height;

  /// Replaces the label (a progress indicator while submitting).
  final Widget? child;

  /// Key for the menu (trailing) half.
  final Key? menuKey;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final outer = Radius.circular(height / 2);
    const inner = Radius.circular(8);
    final style = FilledButton.styleFrom(
      minimumSize: Size(0, height),
      padding: const EdgeInsets.symmetric(horizontal: 20),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: FilledButton(
            key: primaryKey,
            onPressed: onPressed,
            style: style.copyWith(
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.horizontal(
                    left: outer,
                    right: items.isEmpty ? outer : inner,
                  ),
                ),
              ),
            ),
            child:
                child ??
                Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
        ),
        if (items.isNotEmpty) ...[
          const SizedBox(width: 2),
          MenuAnchor(
            menuChildren: [
              for (final item in items)
                MenuItemButton(
                  key: item.key,
                  onPressed: item.onPressed,
                  leadingIcon: item.icon == null ? null : Icon(item.icon),
                  style: item.destructive
                      ? MenuItemButton.styleFrom(foregroundColor: scheme.error)
                      : null,
                  child: item.subtitle == null
                      ? Text(item.label)
                      : ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 280),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(item.label),
                                Text(
                                  item.subtitle!,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
            ],
            builder: (context, controller, _) => FilledButton(
              key: menuKey,
              onPressed:
                  onPressed == null && items.every((i) => i.onPressed == null)
                  ? null
                  : () => controller.isOpen
                        ? controller.close()
                        : controller.open(),
              style: style.copyWith(
                padding: const WidgetStatePropertyAll(EdgeInsets.zero),
                minimumSize: WidgetStatePropertyAll(Size(height - 4, height)),
                shape: WidgetStatePropertyAll(
                  RoundedRectangleBorder(
                    borderRadius: BorderRadius.horizontal(
                      left: inner,
                      right: outer,
                    ),
                  ),
                ),
              ),
              child: Tooltip(
                message: menuTooltip ?? '',
                excludeFromSemantics: menuTooltip == null,
                child: const Icon(Icons.arrow_drop_down),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
