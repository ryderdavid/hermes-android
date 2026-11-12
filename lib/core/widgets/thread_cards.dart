import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/agent_thread.dart';
import '../services/agent_threads_controller.dart';
import '../services/thread_wire.dart';
import '../theme/hermes_theme.dart';
import 'thread_state.dart';
import 'turn_fold.dart';

const _cardMargin = EdgeInsets.symmetric(horizontal: 16, vertical: 4);

/// The card a coordinator turn leaves when it starts threads: one row per
/// thread, each showing that thread's current state.
class ThreadsStartedCard extends StatelessWidget {
  const ThreadsStartedCard({
    required this.threads,
    required this.now,
    this.onOpenThread,
    super.key,
  });

  final List<AgentThread> threads;
  final DateTime now;

  /// `null` when the gateway cannot open threads; rows are then plain.
  final ValueChanged<AgentThread>? onOpenThread;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final open = onOpenThread;
    return Card(
      margin: _cardMargin,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  Icon(
                    Icons.call_split,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      context.l10n.threads_started(threads.length),
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                ],
              ),
            ),
            for (final thread in threads)
              ListTile(
                key: ValueKey<String>('started-thread-${thread.id}'),
                dense: true,
                leading: ThreadStateIcon(thread.state),
                title: Text(
                  threadGoalLabel(context, thread.goal),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(threadMetaLine(context, thread, now: now)),
                trailing: open == null ? null : const Icon(Icons.chevron_right),
                onTap: open == null ? null : () => open(thread),
              ),
          ],
        ),
      ),
    );
  }
}

/// A finished thread's report: goal and outcome, tool count and duration,
/// the summary, and the actions to open or continue the thread.
class ThreadReportCard extends StatelessWidget {
  const ThreadReportCard({
    required this.report,
    this.onOpenThread,
    this.onContinue,
    super.key,
  });

  final ThreadReportAnnotation report;

  /// Opens the thread an entry belongs to. `null` hides Open thread.
  final ValueChanged<ThreadReportEntry>? onOpenThread;

  /// Continues the thread an entry belongs to. `null` (a gateway that cannot
  /// continue threads) hides Continue.
  final ValueChanged<ThreadReportEntry>? onContinue;

  @override
  Widget build(BuildContext context) {
    final entries = report.entries;
    return Card(
      margin: _cardMargin,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (index, entry) in entries.indexed) ...[
              if (index > 0) const Divider(height: 24),
              _ReportEntry(
                entry: entry,
                onOpen: onOpenThread,
                // An early failure warning is not a finished thread yet.
                onContinue: report.earlyFailure ? null : onContinue,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ReportEntry extends StatelessWidget {
  const _ReportEntry({required this.entry, this.onOpen, this.onContinue});

  final ThreadReportEntry entry;
  final ValueChanged<ThreadReportEntry>? onOpen;
  final ValueChanged<ThreadReportEntry>? onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tokens = HermesTokens.of(context);
    final goal = threadGoalLabel(context, entry.goal);
    final (icon, color, title) = ThreadOutcome.succeeded(entry.status)
        ? (Icons.task_alt, tokens.success, l10n.thread_report_finished(goal))
        : ThreadOutcome.stopped(entry.status)
        ? (
            Icons.stop_circle_outlined,
            tokens.muted,
            l10n.thread_report_stopped(goal),
          )
        : (Icons.error_outline, tokens.danger, l10n.thread_report_failed(goal));
    final seconds = entry.durationSeconds;
    final meta = [
      if ((entry.toolCount ?? 0) > 0) l10n.thread_tools_count(entry.toolCount!),
      if (seconds != null)
        formatTurnDuration(
          context,
          Duration(milliseconds: (seconds * 1000).round()),
        ),
    ].join(' · ');
    final summary = entry.summary?.trim() ?? '';
    final open = onOpen;
    final continueThread = onContinue;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(title, style: theme.textTheme.labelLarge)),
            if (meta.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                meta,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: tokens.muted,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        SelectionArea(
          child: Text(
            summary.isEmpty ? l10n.thread_report_no_summary : summary,
            maxLines: 16,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: summary.isEmpty ? tokens.muted : null,
            ),
          ),
        ),
        if (open != null || continueThread != null) ...[
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            children: [
              if (open != null)
                TextButton.icon(
                  onPressed: () => open(entry),
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: Text(l10n.thread_open),
                ),
              if (continueThread != null)
                TextButton.icon(
                  onPressed: () => continueThread(entry),
                  icon: const Icon(Icons.reply, size: 18),
                  label: Text(l10n.continue_label),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

/// A thread speaking to the main chat mid-run: an update, or a question
/// that waits for an answer.
///
/// An open question uses the emphasised container and offers Reply and Let
/// coordinator decide. Once it is answered, expired or otherwise closed the
/// card records how, and the actions go.
class ThreadMessageCard extends StatelessWidget {
  const ThreadMessageCard({
    required this.message,
    this.question,
    this.goal,
    this.onOpenThread,
    this.onReply,
    this.onLetCoordinatorDecide,
    super.key,
  });

  final ThreadMessageAnnotation message;

  /// How the question stands. Ignored for an update.
  final ThreadQuestionRecord? question;

  /// The thread's goal when the message itself does not carry it.
  final String? goal;
  final VoidCallback? onOpenThread;

  /// Answers the question. Called with one of the thread's options, or with
  /// `null` to ask the user for free text. `null` (a gateway that cannot
  /// take replies) hides the action.
  final ValueChanged<String?>? onReply;
  final VoidCallback? onLetCoordinatorDecide;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = HermesTokens.of(context);
    final isQuestion = message.isQuestion;
    final record = question;
    final pending = isQuestion && record?.state == ThreadQuestionState.pending;
    final emphasised = isQuestion && (record?.isOpen ?? false);
    final foreground = emphasised ? scheme.onTertiaryContainer : null;
    final name = threadGoalLabel(context, message.goal ?? goal);
    final reply = pending ? onReply : null;
    final decide = pending ? onLetCoordinatorDecide : null;
    final open = onOpenThread;
    final merged = message.mergedCount;

    final outcome = !isQuestion || record == null
        ? null
        : switch (record.state) {
            ThreadQuestionState.pending => null,
            ThreadQuestionState.deciding => l10n.thread_question_deciding,
            ThreadQuestionState.answered => switch ((
              record.answeredBy,
              record.answer,
            )) {
              (ThreadAnsweredBy.coordinator, final answer?) =>
                l10n.thread_question_answered_by_coordinator(answer),
              (ThreadAnsweredBy.coordinator, null) =>
                l10n.thread_question_answered_coordinator_plain,
              (_, final answer?) => l10n.thread_question_answered_by_you(
                answer,
              ),
              (_, null) => l10n.thread_question_answered,
            },
            ThreadQuestionState.expired => l10n.thread_question_expired,
            ThreadQuestionState.cancelled => l10n.thread_question_cancelled,
            ThreadQuestionState.closed => l10n.thread_question_closed,
          };

    return Card(
      margin: _cardMargin,
      color: emphasised ? scheme.tertiaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isQuestion ? Icons.help_outline : Icons.campaign_outlined,
                  size: 18,
                  color: foreground ?? scheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    isQuestion
                        ? l10n.thread_question_title(name)
                        : l10n.thread_update_title(name),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: foreground,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SelectionArea(
              child: Text(
                message.text,
                style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
              ),
            ),
            if (merged != null && merged > 1)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  l10n.thread_updates_merged(merged),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: tokens.muted,
                  ),
                ),
              ),
            if (outcome != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  outcome,
                  key: const Key('thread-question-outcome'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: foreground ?? tokens.muted,
                  ),
                ),
              ),
            if (reply != null && message.options.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final option in message.options)
                      ActionChip(
                        label: Text(option),
                        onPressed: () => reply(option),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              children: [
                if (reply != null)
                  FilledButton.tonal(
                    onPressed: () => reply(null),
                    child: Text(l10n.thread_reply),
                  ),
                if (decide != null)
                  TextButton(
                    onPressed: decide,
                    style: foreground == null
                        ? null
                        : TextButton.styleFrom(foregroundColor: foreground),
                    child: Text(l10n.thread_let_coordinator_decide),
                  ),
                if (open != null)
                  TextButton(
                    onPressed: open,
                    style: foreground == null
                        ? null
                        : TextButton.styleFrom(foregroundColor: foreground),
                    child: Text(l10n.thread_open),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Asks for one piece of text: a reply to a thread, or a follow-up for one.
/// Resolves to the trimmed text, or `null` when cancelled.
Future<String?> showThreadTextDialog(
  BuildContext context, {
  required String title,
  required String hint,
  required String sendLabel,
  String? body,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _ThreadTextDialog(
      title: title,
      hint: hint,
      sendLabel: sendLabel,
      body: body,
    ),
  );
}

class _ThreadTextDialog extends StatefulWidget {
  const _ThreadTextDialog({
    required this.title,
    required this.hint,
    required this.sendLabel,
    this.body,
  });

  final String title;
  final String hint;
  final String sendLabel;
  final String? body;

  @override
  State<_ThreadTextDialog> createState() => _ThreadTextDialogState();
}

class _ThreadTextDialogState extends State<_ThreadTextDialog> {
  final _text = TextEditingController();

  @override
  void initState() {
    super.initState();
    _text.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final text = _text.text.trim();
    return AlertDialog(
      title: Text(widget.title, maxLines: 2, overflow: TextOverflow.ellipsis),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.body case final body?) ...[
            Flexible(child: SingleChildScrollView(child: Text(body))),
            const SizedBox(height: 16),
          ],
          TextField(
            key: const Key('thread-text-field'),
            controller: _text,
            autofocus: true,
            minLines: 1,
            maxLines: 5,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: widget.hint),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.cancel),
        ),
        FilledButton(
          key: const Key('thread-text-send'),
          onPressed: text.isEmpty
              ? null
              : () => Navigator.of(context).pop(text),
          child: Text(widget.sendLabel),
        ),
      ],
    );
  }
}
