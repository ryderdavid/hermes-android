import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/agent_thread.dart';
import '../services/agent_threads_controller.dart';
import '../theme/hermes_theme.dart';
import 'thread_state.dart';

/// Opens the "All" sheet: every thread of the chat, slot usage, stop, stop
/// all, earlier threads, and the gateway-wide pause.
Future<void> showThreadsSheet(
  BuildContext context, {
  required AgentThreadsController controller,
  required ValueChanged<AgentThread> onOpenThread,
}) {
  // Slot usage changes without an event; read it fresh each time.
  controller.refreshStatus();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (sheetContext) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
      ),
      child: ThreadsSheet(
        controller: controller,
        onOpenThread: (thread) {
          Navigator.of(sheetContext).pop();
          onOpenThread(thread);
        },
      ),
    ),
  );
}

class ThreadsSheet extends StatefulWidget {
  const ThreadsSheet({
    required this.controller,
    required this.onOpenThread,
    super.key,
  });

  final AgentThreadsController controller;
  final ValueChanged<AgentThread> onOpenThread;

  @override
  State<ThreadsSheet> createState() => _ThreadsSheetState();
}

class _ThreadsSheetState extends State<ThreadsSheet> {
  bool _showEarlier = false;
  bool _busy = false;

  AgentThreadsController get _controller => widget.controller;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    try {
      await action();
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.threads_action_failed('$error'))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop(AgentThread thread) => _run(() async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    final found = await _controller.stop(thread.id);
    if (!found) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.threads_already_finished)),
      );
    }
  });

  Future<void> _stopAll(int running) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.threads_stop_all_title),
        content: Text(l10n.threads_stop_all_body(running)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            key: const Key('threads-stop-all-confirm'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.threads_stop_all),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    await _run(() async {
      await _controller.stopAll();
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _controller,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tokens = HermesTokens.of(context);
    final active = _controller.activeThreads;
    final earlier = _controller.finishedThreads;
    final running = active.where((thread) => thread.state.isLive).length;
    final used = _controller.slotsInUse;
    final limit = _controller.slotLimit;
    final now = _controller.now;
    final canStop = _controller.support.steer;

    final usage = [
      used != null && limit != null
          ? l10n.threads_slots_in_use(used, limit)
          : l10n.threads_active_count(active.length),
      ?_controller.slotModel,
    ].join(' · ');

    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
            child: Semantics(
              header: true,
              child: Text(
                l10n.threads_title,
                style: theme.textTheme.titleLarge,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text(
              usage,
              key: const Key('threads-sheet-usage'),
              style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
            ),
          ),
          for (final thread in active)
            _ThreadTile(
              thread: thread,
              now: now,
              onTap: () => widget.onOpenThread(thread),
              trailing: thread.state.isLive && canStop
                  ? IconButton(
                      key: ValueKey<String>('thread-stop-${thread.id}'),
                      onPressed: _busy ? null : () => _stop(thread),
                      icon: const Icon(Icons.stop_circle_outlined),
                      tooltip: l10n.threads_stop_tooltip,
                    )
                  : const Icon(Icons.chevron_right),
            ),
          if (earlier.isNotEmpty)
            ListTile(
              key: const Key('threads-earlier'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 24),
              leading: const Icon(Icons.history),
              title: Text(l10n.threads_earlier),
              subtitle: Text(l10n.threads_earlier_count(earlier.length)),
              trailing: Icon(
                _showEarlier ? Icons.expand_less : Icons.expand_more,
              ),
              onTap: () => setState(() => _showEarlier = !_showEarlier),
            ),
          if (_showEarlier)
            for (final thread in earlier)
              _ThreadTile(
                thread: thread,
                now: now,
                onTap: () => widget.onOpenThread(thread),
                trailing: const Icon(Icons.chevron_right),
              ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Row(
              children: [
                OutlinedButton.icon(
                  key: const Key('threads-pause'),
                  onPressed: _busy
                      ? null
                      : () => _run(
                          () => _controller.setPaused(!_controller.paused),
                        ),
                  icon: Icon(
                    _controller.paused ? Icons.play_arrow : Icons.pause,
                  ),
                  label: Text(
                    _controller.paused
                        ? l10n.threads_resume_new
                        : l10n.threads_pause_new,
                  ),
                ),
                const Spacer(),
                if (canStop)
                  TextButton(
                    key: const Key('threads-stop-all'),
                    onPressed: _busy || running == 0
                        ? null
                        : () => _stopAll(running),
                    style: TextButton.styleFrom(foregroundColor: tokens.danger),
                    child: Text(l10n.threads_stop_all),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
            child: Text(
              _controller.paused
                  ? l10n.threads_paused_gateway_wide
                  : l10n.threads_pause_gateway_wide,
              key: const Key('threads-pause-scope'),
              style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadTile extends StatelessWidget {
  const _ThreadTile({
    required this.thread,
    required this.now,
    required this.onTap,
    required this.trailing,
  });

  final AgentThread thread;
  final DateTime now;
  final VoidCallback onTap;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      key: ValueKey<String>('thread-tile-${thread.id}'),
      contentPadding: const EdgeInsets.symmetric(horizontal: 24),
      leading: ThreadStateIcon(thread.state, size: 20),
      title: Text(
        threadGoalLabel(context, thread.goal),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(threadMetaLine(context, thread, now: now)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}
