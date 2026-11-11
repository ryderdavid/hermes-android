import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/hermes_theme.dart';

/// A turn's working time as "2m 24s", "45s" or "1h 5m".
String formatTurnDuration(BuildContext context, Duration duration) {
  final l10n = context.l10n;
  final seconds = duration.inSeconds < 1 ? 1 : duration.inSeconds;
  if (seconds < 60) return l10n.duration_seconds(seconds);
  if (seconds < 3600) {
    return l10n.duration_minutes_seconds(seconds ~/ 60, seconds % 60);
  }
  return l10n.duration_hours_minutes(seconds ~/ 3600, (seconds % 3600) ~/ 60);
}

/// The line a finished turn's steps fold into: "Worked for 2m 24s ›".
///
/// It states how long the turn worked, or how many steps it took when the
/// time is not known, and marks a turn in which something failed. Tapping it
/// calls [onTap]; the caller owns the fold state and passes it as [unfolded].
class TurnFoldLine extends StatelessWidget {
  const TurnFoldLine({
    required this.stepCount,
    this.duration,
    this.failureCount = 0,
    this.unfolded = false,
    this.onTap,
    super.key,
  });

  static const double minHeight = 48;

  final Duration? duration;
  final int stepCount;
  final int failureCount;
  final bool unfolded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tokens = HermesTokens.of(context);
    final label = duration == null
        ? l10n.turn_fold_steps(stepCount)
        : l10n.turn_fold_worked_for(formatTurnDuration(context, duration!));
    final failed = failureCount > 0
        ? l10n.turn_fold_failed(failureCount)
        : null;

    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: [label, ?failed].join(', '),
      onTap: onTap,
      onTapHint: onTap == null
          ? null
          : unfolded
          ? l10n.turn_fold_hide_steps
          : l10n.turn_fold_show_steps,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 24, 0),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: tokens.muted,
                    ),
                  ),
                ),
                const SizedBox(width: HermesSpacing.xs),
                Icon(
                  unfolded ? Icons.expand_less : Icons.chevron_right,
                  size: 18,
                  color: tokens.muted,
                ),
                if (failed != null) ...[
                  const SizedBox(width: HermesSpacing.sm),
                  Icon(Icons.error_outline, size: 16, color: tokens.danger),
                  const SizedBox(width: HermesSpacing.xs),
                  Text(
                    failed,
                    maxLines: 1,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: tokens.danger,
                    ),
                  ),
                ],
                const SizedBox(width: HermesSpacing.md),
                Expanded(
                  child: Divider(color: theme.colorScheme.outlineVariant),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
