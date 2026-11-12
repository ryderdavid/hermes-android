import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/agent_thread.dart';
import '../theme/hermes_theme.dart';
import 'turn_fold.dart';

/// The state mark of a thread: a spinner while it runs, an icon otherwise.
class ThreadStateIcon extends StatelessWidget {
  const ThreadStateIcon(this.state, {this.size = 16, super.key});

  final AgentThreadState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = HermesTokens.of(context);
    final (icon, color) = switch (state) {
      AgentThreadState.running => (null, null),
      AgentThreadState.needsYou => (Icons.help_outline, tokens.warning),
      AgentThreadState.done => (Icons.check_circle_outline, tokens.success),
      AgentThreadState.failed => (Icons.error_outline, tokens.danger),
      AgentThreadState.stopped => (Icons.stop_circle_outlined, tokens.muted),
      AgentThreadState.queued => (Icons.schedule, tokens.muted),
    };
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size + 2,
        child: icon == null
            ? Padding(
                padding: const EdgeInsets.all(1),
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Icon(icon, size: size + 2, color: color),
      ),
    );
  }
}

String threadStateLabel(BuildContext context, AgentThreadState state) {
  final l10n = context.l10n;
  return switch (state) {
    AgentThreadState.running => l10n.thread_state_running,
    AgentThreadState.needsYou => l10n.thread_state_needs_you,
    AgentThreadState.done => l10n.thread_state_done,
    AgentThreadState.failed => l10n.thread_state_failed,
    AgentThreadState.stopped => l10n.thread_state_stopped,
    AgentThreadState.queued => l10n.thread_state_queued,
  };
}

/// The thread's goal, or a generic name while the gateway has not said.
String threadGoalLabel(BuildContext context, String? goal) {
  final trimmed = goal?.trim() ?? '';
  return trimmed.isEmpty ? context.l10n.thread_untitled : trimmed;
}

/// "Running · 7 tools · 2m 4s", with [model] appended when [withModel].
String threadMetaLine(
  BuildContext context,
  AgentThread thread, {
  required DateTime now,
  bool withModel = false,
}) {
  final elapsed = thread.elapsed(now);
  return [
    threadStateLabel(context, thread.state),
    if (thread.toolCount > 0) context.l10n.thread_tools_count(thread.toolCount),
    if (elapsed != null && thread.state != AgentThreadState.queued)
      formatTurnDuration(context, elapsed),
    if (withModel && (thread.model?.isNotEmpty ?? false)) thread.model!,
  ].join(' · ');
}
