/// The Hermes component kit.
///
/// Small, token-driven widgets shared by every screen so status, empty,
/// loading, and error situations look and behave the same everywhere. See
/// `docs/ANDROID_DAILY_DRIVER_ROADMAP.md` ("Interface overhaul").
library;

import 'package:flutter/material.dart';

import '../expressive/segmented_list.dart';
import '../theme/hermes_theme.dart';

import 'package:hermes_android/core/l10n/l10n.dart';
/// Default wording for each semantic status, phrased for a person, not a state
/// machine: a blocked turn is something that "needs you".
String defaultStatusLabel(BuildContext context, HermesStatus status) {
  switch (status) {
    case HermesStatus.running:
      return context.l10n.status_running;
    case HermesStatus.blocked:
      return context.l10n.needs_you;
    case HermesStatus.failed:
      return context.l10n.status_failed;
    case HermesStatus.completed:
      return context.l10n.status_done;
    case HermesStatus.idle:
      return context.l10n.status_idle;
  }
}

/// A compact, color-coded state badge.
class StatusChip extends StatelessWidget {
  final HermesStatus status;
  final String? label;

  const StatusChip({required this.status, this.label, super.key});

  @override
  Widget build(BuildContext context) {
    final tokens = HermesTokens.of(context);
    final color = tokens.colorForStatus(status);
    final text = label ?? defaultStatusLabel(context, status);
    final fill = color.withValues(alpha: 0.16);
    // Chips sit on raised surfaces; keep 12sp text at AA on the tinted fill.
    final ink = legibleOn(
      color,
      Color.alphaBlend(fill, tokens.raised),
      ink: tokens.onSurface,
    );

    return Semantics(
      label: text,
      container: true,
      child: ExcludeSemantics(
        child: Container(
          // Material 3 Expressive status label: a tonal pill, no outline.
          padding: const EdgeInsets.symmetric(
            horizontal: HermesSpacing.sm + 2,
            vertical: 3,
          ),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(HermesRadius.md),
          ),
          child: Text(
            text,
            style: tokens.typography.label.copyWith(
              color: ink,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// A list-section title with an optional count and a single trailing action.
class SectionHeader extends StatelessWidget {
  final String title;
  final int? count;
  final String? actionLabel;
  final VoidCallback? onAction;

  const SectionHeader({
    required this.title,
    this.count,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = HermesTokens.of(context);
    final showAction = actionLabel != null && onAction != null;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        HermesSpacing.lg,
        HermesSpacing.lg,
        HermesSpacing.sm,
        HermesSpacing.sm,
      ),
      child: Row(
        children: [
          // Material 3 Expressive list section title: emphasized label in
          // the primary role, the count beside it in the muted role.
          Flexible(
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (count != null) ...[
            const SizedBox(width: HermesSpacing.sm),
            Text(
              '$count',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                color: tokens.muted,
              ),
            ),
          ],
          const Spacer(),
          if (showAction)
            TextButton(
              onPressed: onAction,
              child: Text(
                actionLabel!,
                style: tokens.typography.label.copyWith(color: tokens.accent),
              ),
            ),
        ],
      ),
    );
  }
}

/// The standard Hermes surface: a bordered, flat card.
///
/// Passing [status] tints the border and background so urgent work reads as
/// urgent without a second widget.
class HermesCard extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final HermesStatus? status;
  final EdgeInsetsGeometry padding;

  const HermesCard({
    required this.child,
    this.onTap,
    this.onLongPress,
    this.status,
    this.padding = const EdgeInsets.all(HermesSpacing.lg),
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = HermesTokens.of(context);
    final accent = status == null ? null : tokens.colorForStatus(status!);

    // Material 3 Expressive: a borderless tonal tile. Inside a segmented
    // group it takes the group's corners; alone it is a 20dp card. Status
    // tints the fill rather than adding an outline.
    final scheme = Theme.of(context).colorScheme;
    final radius =
        SegmentScope.maybeOf(context)?.radius() ?? HermesRadius.card;
    final base = scheme.surfaceContainerLow;
    final fill = accent == null
        ? base
        : Color.alphaBlend(accent.withValues(alpha: 0.12), base);

    final surface = Container(
      constraints: const BoxConstraints(minHeight: 48),
      padding: padding,
      child: child,
    );

    return Material(
      color: fill,
      borderRadius: radius,
      clipBehavior: Clip.antiAlias,
      child: onTap == null && onLongPress == null
          ? surface
          : InkWell(onTap: onTap, onLongPress: onLongPress, child: surface),
    );
  }
}

/// A designed empty state: what is missing, why it matters, one way forward.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final tokens = HermesTokens.of(context);
    final showAction = actionLabel != null && onAction != null;

    return Padding(
      padding: const EdgeInsets.all(HermesSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 48, color: tokens.muted),
          const SizedBox(height: HermesSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: tokens.typography.display.copyWith(color: tokens.onSurface),
          ),
          const SizedBox(height: HermesSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: tokens.typography.body.copyWith(color: tokens.muted),
          ),
          if (showAction) ...[
            const SizedBox(height: HermesSpacing.xl),
            FilledButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ],
      ),
    );
  }
}

/// A failure state, or — via [ErrorState.unsupported] — a calm compatibility
/// notice for a gateway that simply does not offer a capability yet.
class ErrorState extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onRetry;
  final bool _informational;

  const ErrorState({
    required this.title,
    required this.message,
    this.onRetry,
    super.key,
  }) : _informational = false;

  /// An older gateway missing a capability is not an error the user caused,
  /// so it must not be styled or worded like a crash.
  const ErrorState.unsupported({
    required this.title,
    required this.message,
    super.key,
  }) : onRetry = null,
       _informational = true;

  @override
  Widget build(BuildContext context) {
    final tokens = HermesTokens.of(context);
    final color = _informational ? tokens.muted : tokens.danger;

    return Padding(
      padding: const EdgeInsets.all(HermesSpacing.xl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _informational ? Icons.info_outline : Icons.error_outline_rounded,
            size: 48,
            color: color,
          ),
          const SizedBox(height: HermesSpacing.lg),
          Text(
            title,
            textAlign: TextAlign.center,
            style: tokens.typography.display.copyWith(color: tokens.onSurface),
          ),
          const SizedBox(height: HermesSpacing.sm),
          Text(
            message,
            textAlign: TextAlign.center,
            style: tokens.typography.body.copyWith(color: tokens.muted),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: HermesSpacing.xl),
            FilledButton.tonalIcon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.retry),
            ),
          ],
        ],
      ),
    );
  }
}

/// A compact error message inside a form or dialog, on the scheme's error
/// container so it reads as an error in every color scheme.
class InlineErrorBanner extends StatelessWidget {
  final String message;

  const InlineErrorBanner({required this.message, super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(HermesSpacing.md),
      margin: const EdgeInsets.only(bottom: HermesSpacing.md),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: HermesRadius.card,
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: scheme.onErrorContainer, size: 18),
          const SizedBox(width: HermesSpacing.sm),
          Expanded(
            child: Text(
              message,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Placeholder rows shown while real content loads.
///
/// Preferred over a spinner: it preserves layout, so content does not jump
/// into place when it arrives.
class LoadingSkeleton extends StatefulWidget {
  final int rows;

  const LoadingSkeleton({this.rows = 3, super.key});

  @override
  State<LoadingSkeleton> createState() => _LoadingSkeletonState();
}

class _LoadingSkeletonState extends State<LoadingSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tokens = HermesTokens.of(context);

    return Semantics(
      label: context.l10n.loading,
      container: true,
      child: Column(
        children: List.generate(widget.rows, (index) {
          return Padding(
            key: Key('skeleton-row-$index'),
            padding: const EdgeInsets.fromLTRB(
              HermesSpacing.lg,
              HermesSpacing.sm,
              HermesSpacing.lg,
              HermesSpacing.sm,
            ),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                return Container(
                  height: 64,
                  decoration: BoxDecoration(
                    color: tokens.raised.withValues(
                      alpha: 0.5 + _controller.value * 0.35,
                    ),
                    borderRadius: HermesRadius.card,
                    border: Border.all(color: tokens.border),
                  ),
                );
              },
            ),
          );
        }),
      ),
    );
  }
}
