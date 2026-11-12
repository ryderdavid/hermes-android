import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/agent_thread.dart';
import 'thread_state.dart';

/// The chat's thread roster: one chip per thread under the context header.
///
/// Threads that need the user come first and use the emphasised container.
/// The strip takes no space when the chat has no threads.
class ThreadsStrip extends StatelessWidget {
  const ThreadsStrip({
    required this.threads,
    required this.onOpenThread,
    required this.onShowAll,
    this.paused = false,
    super.key,
  });

  /// How many finished threads keep a chip. Older ones are in the sheet.
  static const maxFinishedChips = 3;

  static const double height = 52;

  /// Threads in roster order: needs-you first.
  final List<AgentThread> threads;
  final ValueChanged<AgentThread> onOpenThread;
  final VoidCallback onShowAll;

  /// New threads are paused gateway-wide.
  final bool paused;

  @override
  Widget build(BuildContext context) {
    if (threads.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    var finished = 0;
    final shown = [
      for (final thread in threads)
        if (thread.state.isActive || finished++ < maxFinishedChips) thread,
    ];

    return Semantics(
      container: true,
      label: l10n.threads_title,
      child: Container(
        key: const Key('threads-strip'),
        height: height,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
        ),
        // "All" stays put at the end while the chips scroll under it, so the
        // sheet is one tap away however many threads there are.
        child: Row(
          children: [
            Expanded(
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
                children: [
                  if (paused) ...[
                    Chip(
                      key: const Key('threads-strip-paused'),
                      avatar: const Icon(Icons.pause, size: 16),
                      label: Text(l10n.threads_paused_chip),
                    ),
                    const SizedBox(width: 8),
                  ],
                  for (final thread in shown) ...[
                    _ThreadChip(
                      thread: thread,
                      onPressed: () => onOpenThread(thread),
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
              child: ActionChip(
                key: const Key('threads-strip-all'),
                avatar: const Icon(Icons.view_list_outlined, size: 16),
                label: Text(l10n.threads_all),
                onPressed: onShowAll,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThreadChip extends StatelessWidget {
  const _ThreadChip({required this.thread, required this.onPressed});

  final AgentThread thread;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final waiting = thread.state == AgentThreadState.needsYou;
    final goal = threadGoalLabel(context, thread.goal);
    return Semantics(
      button: true,
      label: '$goal, ${threadStateLabel(context, thread.state)}',
      excludeSemantics: true,
      onTap: onPressed,
      child: InputChip(
        key: ValueKey<String>('thread-chip-${thread.id}'),
        avatar: ThreadStateIcon(thread.state, size: 14),
        label: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 200),
          child: Text(
            goal,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: waiting
                ? TextStyle(
                    color: scheme.onTertiaryContainer,
                    fontWeight: FontWeight.w600,
                  )
                : null,
          ),
        ),
        backgroundColor: waiting ? scheme.tertiaryContainer : null,
        onPressed: onPressed,
      ),
    );
  }
}
