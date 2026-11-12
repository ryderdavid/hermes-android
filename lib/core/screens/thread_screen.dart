import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/agent_thread.dart';
import '../services/agent_threads_controller.dart';
import '../services/thread_view_controller.dart';
import '../services/turn_fold_pins.dart';
import '../theme/hermes_theme.dart';
import '../utils/chat_display_items.dart';
import '../utils/thread_transcript.dart';
import '../widgets/activity_detail_sheet.dart';
import '../widgets/activity_row.dart';
import '../widgets/thread_state.dart';
import '../widgets/thread_steer_bar.dart';
import '../widgets/turn_fold.dart';
import 'chat_screen.dart' show MessageBubble;

/// One thread, full screen: the task the coordinator gave it, what it has
/// done, and the bar that steers, stops or continues it.
///
/// It is pushed over the parent chat, which stays mounted underneath, so
/// opening and closing it leaves the chat's draft, scroll position and
/// composer as they were. The view is read-only apart from the bar.
class ThreadScreen extends StatefulWidget {
  const ThreadScreen({
    required this.threads,
    required this.threadId,
    required this.chatTitle,
    required this.loadHistory,
    this.pollInterval = const Duration(seconds: 2),
    super.key,
  });

  final AgentThreadsController threads;
  final String threadId;

  /// The parent chat's title, for "Thread of …".
  final String chatTitle;
  final ThreadHistoryPageLoader? loadHistory;
  final Duration pollInterval;

  /// Opens [threadId] over the current route.
  static Future<void> open(
    BuildContext context, {
    required AgentThreadsController threads,
    required String threadId,
    required String chatTitle,
    required ThreadHistoryPageLoader? loadHistory,
  }) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ThreadScreen(
          threads: threads,
          threadId: threadId,
          chatTitle: chatTitle,
          loadHistory: loadHistory,
        ),
      ),
    );
  }

  @override
  State<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends State<ThreadScreen>
    with WidgetsBindingObserver {
  late final ThreadViewController _view;
  final TurnFoldPins _foldPins = TurnFoldPins();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _view = ThreadViewController(
      threads: widget.threads,
      threadId: widget.threadId,
      loadHistory: widget.loadHistory,
      pollInterval: widget.pollInterval,
    )..setVisible(true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Nothing is polled for a view nobody is looking at.
    _view.setVisible(state == AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _view.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _view,
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tokens = HermesTokens.of(context);
    final thread = _view.thread;
    final goal = threadGoalLabel(context, thread?.goal);
    final live = _view.isLive;

    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(goal, maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              l10n.thread_of_chat(
                widget.chatTitle.trim().isEmpty
                    ? l10n.untitled_chat
                    : widget.chatTitle,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelSmall?.copyWith(color: tokens.muted),
            ),
          ],
        ),
        bottom: thread == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(40),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      ThreadStateIcon(thread.state, size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          threadMetaLine(
                            context,
                            thread,
                            now: widget.threads.now,
                            withModel: true,
                          ),
                          key: const Key('thread-meta'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.labelMedium,
                        ),
                      ),
                      if (live) ...[
                        const SizedBox(width: 8),
                        Icon(
                          Icons.fiber_manual_record,
                          size: 10,
                          color: tokens.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.thread_live,
                          key: const Key('thread-live'),
                          style: theme.textTheme.labelSmall,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
      ),
      body: Column(
        children: [
          Expanded(child: _buildTranscript(context, thread)),
          ThreadSteerBar(controller: widget.threads, threadId: widget.threadId),
        ],
      ),
    );
  }

  Widget _buildTranscript(BuildContext context, AgentThread? thread) {
    final l10n = context.l10n;
    final transcript = _view.transcript;
    final running = thread?.state.isLive ?? false;
    final items = transcript.displayItems(
      running: running,
      foldChoice: (turnId) => _foldPins[turnId],
    );
    for (final fold in items.whereType<ChatTurnFold>()) {
      for (final alias in fold.aliases) {
        _foldPins.alias(alias, fold.id);
      }
    }
    final task = _view.task;
    final status = _view.historyStatus;
    final shown = [
      for (final item in items)
        if (!(item is Map<String, dynamic> &&
            item[ThreadTranscript.taskMarker] == true))
          item,
    ];

    return ListView(
      key: const Key('thread-transcript'),
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (task != null)
          Card(
            key: const Key('thread-task'),
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListTile(
              leading: const Icon(Icons.assignment_outlined),
              title: Text(l10n.thread_task_title),
              subtitle: SelectionArea(child: Text(task)),
            ),
          ),
        if (_view.tailTruncated)
          _Note(
            key: const Key('thread-tail-truncated'),
            icon: Icons.history,
            text: l10n.thread_live_tail_truncated,
          ),
        if (status == ThreadHistoryStatus.partial)
          _Note(
            key: const Key('thread-history-partial'),
            icon: Icons.history_toggle_off,
            text: l10n.thread_history_partial,
            onRetry: _view.retryHistory,
          ),
        for (final item in shown) _buildItem(context, item, transcript),
        if (status == ThreadHistoryStatus.loading)
          const Padding(
            padding: EdgeInsets.all(16),
            child: LinearProgressIndicator(),
          ),
        if (status == ThreadHistoryStatus.unavailable)
          _Note(
            key: const Key('thread-history-unavailable'),
            icon: Icons.cloud_off_outlined,
            text: l10n.thread_history_unavailable,
            onRetry: thread?.childSessionId == null ? null : _view.retryHistory,
          ),
        if (shown.isEmpty &&
            status != ThreadHistoryStatus.loading &&
            status != ThreadHistoryStatus.unavailable)
          _Note(
            key: const Key('thread-empty'),
            icon: Icons.hourglass_empty,
            text: l10n.thread_no_activity_yet,
          ),
      ],
    );
  }

  Widget _buildItem(
    BuildContext context,
    Object? item,
    ThreadTranscript transcript,
  ) {
    if (item is ChatTurnFold) {
      return TurnFoldLine(
        key: ValueKey<String>('turn-fold-${item.id}'),
        duration: item.duration,
        stepCount: item.stepCount,
        failureCount: item.failureCount,
        unfolded: item.unfolded,
        onTap: () => setState(() => _foldPins.pin(item.id, !item.unfolded)),
      );
    }
    if (item is ChatActivityStep) {
      void open() => showActivityDetailSheet(
        context,
        step: item,
        messages: transcript.messages,
      );
      final key = ValueKey<String>('activity-${item.id}');
      return item.isReasoning
          ? ActivityRow.reasoning(
              key: key,
              headline: item.reasoningHeadline,
              running: item.isRunning,
              onTap: open,
            )
          : ActivityRow.tool(key: key, activity: item.activity!, onTap: open);
    }
    if (item is ChatActivityGroupItem) {
      return ActivityRow.group(
        key: ValueKey<String>('activity-${item.id}'),
        first: item.steps.first.activity!,
        count: item.steps.length,
        onTap: () => showActivityDetailSheet(
          context,
          group: item,
          messages: transcript.messages,
        ),
      );
    }
    if (item is Map<String, dynamic>) {
      return MessageBubble(
        content: (item['_display_content'] as String?) ?? '',
        isUser: item['role'] == 'user',
        metadata: item,
      );
    }
    return const SizedBox.shrink();
  }
}

/// A plain line that says what the view could not show.
class _Note extends StatelessWidget {
  const _Note({
    required this.icon,
    required this.text,
    this.onRetry,
    super.key,
  });

  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = HermesTokens.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 8, 16, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tokens.muted),
          const SizedBox(width: HermesSpacing.md),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
            ),
          ),
          if (onRetry != null)
            TextButton(onPressed: onRetry, child: Text(context.l10n.retry)),
        ],
      ),
    );
  }
}
