import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/agent_thread.dart';
import '../screens/thread_screen.dart';
import '../services/agent_threads_controller.dart';
import '../services/coordinator_mode_store.dart';
import '../services/thread_view_controller.dart';
import '../services/thread_wire.dart';
import '../services/turn_notification_service.dart';
import '../utils/chat_display_items.dart';
import 'thread_cards.dart';
import 'threads_sheet.dart';
import 'threads_strip.dart';

/// Everything a chat needs for threads and coordinator mode, kept out of
/// `ChatScreen` so that file only gains hook points.
///
/// It owns the chat's [AgentThreadsController] and its coordinator-mode
/// setting, builds the roster strip, the thread cards and the menu item, and
/// carries out their actions. It notifies when the coordinator setting
/// changes; listen to [threads] for roster changes.
class ChatThreadsBinding extends ChangeNotifier {
  ChatThreadsBinding({
    required AgentThreadsGateway? gateway,
    required this.connectionIdentity,
    required this.connectionId,
    required this.sessionId,
    required this.isNewChat,
    required this.chatTitle,
    required this.isAppInBackground,
    required this.notifications,
    required this.notificationText,
    required this.loadHistory,
    required this.sendCoordinatorPrompt,
    required this.onThreadActivity,
    Future<CoordinatorModeStore>? store,
    DateTime Function()? clock,
  }) : threads = AgentThreadsController(gateway: gateway, clock: clock),
       _store = store ?? CoordinatorModeStore.open() {
    threads
      ..onThreadFinished = _onThreadFinished
      ..onThreadQuestion = _onThreadQuestion;
    unawaited(_restore());
  }

  final AgentThreadsController threads;
  final String connectionIdentity;
  final String connectionId;

  /// The chat's mobile session id.
  final String sessionId;

  /// A chat that has never been sent to the gateway: it takes the "new chats
  /// use coordinator mode" default.
  final bool isNewChat;
  final String Function() chatTitle;
  final bool Function() isAppInBackground;
  final TurnNotificationService notifications;
  final ThreadNotificationText Function() notificationText;
  final ThreadHistoryPageLoader? loadHistory;

  /// Sends one prompt to the coordinator as the user. Returns false when the
  /// chat cannot send right now.
  final Future<bool> Function(String prompt) sendCoordinatorPrompt;

  /// A thread finished or delivered a message: the gateway has started, or
  /// will start, a parent turn the chat did not ask for.
  final VoidCallback onThreadActivity;

  final Future<CoordinatorModeStore> _store;
  String? _storedSessionId;
  bool _coordinatorOn = false;
  bool _restored = false;
  bool _bound = false;
  bool _modeApplied = false;
  bool _disposed = false;

  ThreadSupport get support => threads.support;

  /// The gateway can list, open, steer and stop threads. Without it the chat
  /// keeps the read-only task list.
  bool get showsThreads => support.roster;

  /// The user's choice for this chat.
  bool get coordinatorOn => _coordinatorOn;

  /// The gateway can run this chat in coordinator mode.
  bool get coordinatorAvailable => support.coordinatorMode;

  /// Coordinator mode is on and in effect: what the app bar label shows.
  bool get coordinatorActive => _coordinatorOn && coordinatorAvailable;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _restore() async {
    final store = await _store;
    if (_disposed) return;
    final explicit = store.read(
      connectionIdentity: connectionIdentity,
      sessionId: sessionId,
    );
    final resolved = explicit ?? (isNewChat && store.newChatsDefault);
    // A toggle made before the read finished is the newer choice.
    if (!_restored) _coordinatorOn = resolved;
    _restored = true;
    if (_coordinatorOn && (explicit == null || _storedSessionId != null)) {
      // The default is taken once, when the chat is new. From here on the
      // chat has its own value and a later change of the default leaves it.
      // A session that bound before this read finished also gets its copy
      // under the stored id.
      await _save(store);
    }
    _notify();
    if (_coordinatorOn) unawaited(_applyModeQuietly());
  }

  Future<void> _save(CoordinatorModeStore store) async {
    await store.save(
      connectionIdentity: connectionIdentity,
      sessionId: sessionId,
      enabled: _coordinatorOn,
    );
    // A new chat is listed under its stored id after a restart.
    final stored = _storedSessionId;
    if (stored != null && stored != sessionId) {
      await store.save(
        connectionIdentity: connectionIdentity,
        sessionId: stored,
        enabled: _coordinatorOn,
      );
    }
  }

  /// The chat bound its gateway session: on open, and again after every
  /// reconnect. Seeds the roster and re-applies coordinator mode.
  void onSessionBound([String? storedSessionId]) {
    _bound = true;
    _modeApplied = false;
    if (storedSessionId != null &&
        storedSessionId.isNotEmpty &&
        storedSessionId != _storedSessionId) {
      _storedSessionId = storedSessionId;
      if (_restored && _coordinatorOn) {
        unawaited(_store.then(_save));
      }
    }
    unawaited(threads.seed());
    if (_coordinatorOn) unawaited(_applyModeQuietly());
  }

  /// Sends `session.mode.set` for the current choice. The prompt text is
  /// never touched: on a gateway without the capability nothing is sent.
  Future<void> _applyMode() async {
    final gateway = threads.gateway;
    if (gateway == null || !_bound || !gateway.support.coordinatorMode) return;
    final value = _coordinatorOn;
    await gateway.setCoordinatorMode(value);
    if (value == _coordinatorOn) _modeApplied = true;
  }

  /// [_applyMode] for a bind, where nobody waits for the outcome. A failure
  /// (a socket that dropped again, a gateway error) leaves the mode
  /// unapplied; the next bind or the next send applies it.
  Future<void> _applyModeQuietly() async {
    try {
      await _applyMode();
    } catch (_) {
      // Retried on the next bind and before the next prompt.
    }
  }

  /// Makes sure the gateway session is in coordinator mode before a prompt
  /// leaves, so the first prompt of a new chat already runs in it. A failure
  /// does not hold the prompt back.
  Future<void> applyCoordinatorModeBeforeSend() async {
    final gateway = threads.gateway;
    if (gateway == null || !_coordinatorOn || _modeApplied) return;
    try {
      // Binding the session is also what tells us what the gateway can do.
      await gateway.ensureSession();
      _bound = true;
      await _applyMode();
    } catch (_) {
      // The next bind applies it again.
    }
  }

  /// Flips the chat's coordinator mode. Throws when the gateway refused the
  /// change; the choice is stored either way and applied at the next bind.
  Future<void> toggleCoordinator() async {
    if (!coordinatorAvailable) return;
    _restored = true;
    _coordinatorOn = !_coordinatorOn;
    _modeApplied = false;
    _notify();
    await _save(await _store);
    await _applyMode();
  }

  // ── Notifications ──────────────────────────────────────────────────────

  void _onThreadFinished(AgentThread thread) {
    onThreadActivity();
    if (!isAppInBackground()) return;
    final failed = thread.state == AgentThreadState.failed;
    unawaited(
      notifications.showThreadEvent(
        event: failed
            ? ThreadNotificationEvent.failed
            : ThreadNotificationEvent.finished,
        text: notificationText(),
        threadId: thread.id,
        chatTitle: chatTitle(),
        goal: thread.goal,
        detail: thread.summary,
        eventId: thread.delegationId,
        sessionId: sessionId,
        connectionId: connectionId,
      ),
    );
  }

  void _onThreadQuestion(AgentThread thread, AgentThreadQuestion question) {
    if (!isAppInBackground()) return;
    unawaited(
      notifications.showThreadEvent(
        event: ThreadNotificationEvent.question,
        text: notificationText(),
        threadId: thread.id,
        chatTitle: chatTitle(),
        goal: thread.goal,
        detail: question.text,
        eventId: question.questionId,
        sessionId: sessionId,
        connectionId: connectionId,
      ),
    );
  }

  /// Applies one gateway event. Returns whether it was a thread event.
  bool applyEvent(String type, Map<String, dynamic> data) {
    final handled = threads.applyEvent(type, data);
    if (handled && type == ThreadEventType.message) onThreadActivity();
    return handled;
  }

  // ── Widgets ────────────────────────────────────────────────────────────

  /// The roster strip. Takes no space without thread support or threads.
  Widget buildStrip(BuildContext context) {
    return ListenableBuilder(
      listenable: threads,
      builder: (context, _) {
        if (!showsThreads || !threads.hasThreads) {
          return const SizedBox.shrink();
        }
        return ThreadsStrip(
          threads: threads.threads,
          paused: threads.paused,
          onOpenThread: (thread) => openThread(context, thread.id),
          onShowAll: () => showThreadsSheet(
            context,
            controller: threads,
            onOpenThread: (thread) => openThread(context, thread.id),
          ),
        );
      },
    );
  }

  Future<void> openThread(BuildContext context, String threadId) {
    return ThreadScreen.open(
      context,
      threads: threads,
      threadId: threadId,
      chatTitle: chatTitle(),
      loadHistory: loadHistory,
    );
  }

  /// The Coordinator mode entry of the chat menu. Disabled, with the reason,
  /// on a gateway that does not offer the mode.
  PopupMenuEntry<String> buildMenuItem(BuildContext context) {
    final l10n = context.l10n;
    final available = coordinatorAvailable;
    return CheckedPopupMenuItem<String>(
      key: const Key('chat-menu-coordinator'),
      value: menuValue,
      enabled: available,
      checked: coordinatorActive,
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        enabled: available,
        title: Text(l10n.coordinator_mode),
        subtitle: Text(
          available
              ? l10n.coordinator_mode_subtitle
              : l10n.coordinator_mode_unavailable,
        ),
      ),
    );
  }

  static const menuValue = 'coordinator';

  /// Handles the menu item. Reports a gateway refusal in a snack bar.
  Future<void> onMenuSelected(BuildContext context) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    final l10n = context.l10n;
    try {
      await toggleCoordinator();
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.coordinator_mode_failed('$error'))),
      );
    }
  }

  /// The Coordinator label under the chat title, or nothing while the mode
  /// is off or the gateway does not offer it.
  Widget buildAppBarLabel(BuildContext context) {
    if (!coordinatorActive) return const SizedBox.shrink();
    final theme = Theme.of(context);
    return Padding(
      key: const Key('chat-coordinator-label'),
      padding: const EdgeInsets.only(right: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.hub_outlined, size: 14, color: theme.colorScheme.primary),
          const SizedBox(width: 4),
          Text(
            context.l10n.coordinator_label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
    );
  }

  /// The widget for a thread item of the chat list, or `null` when [item]
  /// is not one. [busy] says the chat is sending or streaming.
  Widget? buildItem(BuildContext context, Object? item, {required bool busy}) {
    if (item is ChatThreadsStartedItem) {
      return ThreadsStartedCard(
        key: ValueKey<String>(item.id),
        // The item holds the threads as they were projected; the roster has
        // their state now.
        threads: [
          for (final thread in item.threads)
            threads.thread(thread.id) ?? thread,
        ],
        now: threads.now,
        onOpenThread: showsThreads
            ? (thread) => openThread(context, thread.id)
            : null,
      );
    }
    if (item is ChatThreadReportItem) {
      final report = _resolved(item.report);
      return ThreadReportCard(
        key: ValueKey<String>(item.id),
        report: report,
        onOpenThread: showsThreads
            ? (entry) => _openReported(context, entry)
            : null,
        onContinue: support.continueThreads
            ? (entry) => _continueReported(context, entry)
            : null,
      );
    }
    if (item is ChatThreadMessageItem) {
      final message = item.message;
      final thread = threads.thread(message.subagentId);
      final questionId = message.questionId;
      return ThreadMessageCard(
        key: ValueKey<String>(item.id),
        message: message,
        goal: thread?.goal,
        question: questionId == null
            ? null
            : threads.questionRecord(message.subagentId, questionId),
        onOpenThread: showsThreads && thread != null
            ? () => openThread(context, thread.id)
            : null,
        onReply: support.messages && questionId != null
            ? (preset) => _reply(context, message, preset)
            : null,
        onLetCoordinatorDecide: support.messages && questionId != null && !busy
            ? () => _letCoordinatorDecide(context, message)
            : null,
      );
    }
    return null;
  }

  /// Fills in the thread id of report entries the gateway did not name (a
  /// row read without its annotation) from the roster: by delegation, then
  /// by goal.
  ThreadReportAnnotation _resolved(ThreadReportAnnotation report) {
    if (report.entries.every((entry) => entry.subagentId != null)) {
      return report;
    }
    final known = threads.threads
        .where((thread) => !thread.id.startsWith('failed:'))
        .toList();
    String? match(ThreadReportEntry entry) {
      final sameUnit = [
        for (final thread in known)
          if (report.delegationId != null &&
              thread.delegationId == report.delegationId)
            thread,
      ];
      if (sameUnit.length == 1 && report.entries.length == 1) {
        return sameUnit.single.id;
      }
      final goal = entry.goal?.trim() ?? '';
      if (goal.isEmpty) return null;
      final sameGoal = [
        for (final thread in sameUnit.isEmpty ? known : sameUnit)
          if (thread.goal.trim() == goal) thread,
      ];
      return sameGoal.length == 1 ? sameGoal.single.id : null;
    }

    return ThreadReportAnnotation(
      delegationId: report.delegationId,
      earlyFailure: report.earlyFailure,
      entries: [
        for (final entry in report.entries)
          entry.subagentId != null
              ? entry
              : entry.withFallback(ThreadReportEntry(subagentId: match(entry))),
      ],
    );
  }

  Future<void> _openReported(BuildContext context, ThreadReportEntry entry) {
    final id = entry.subagentId;
    if (id == null) return Future.value();
    // A thread reported before this app session started is not in the
    // roster; the view still opens, with what the report says about it.
    threads.rememberFinished(
      id: id,
      goal: entry.goal,
      status: entry.status,
      toolCount: entry.toolCount,
      durationSeconds: entry.durationSeconds,
      summary: entry.summary,
    );
    return openThread(context, id);
  }

  Future<void> _continueReported(
    BuildContext context,
    ThreadReportEntry entry,
  ) async {
    final id = entry.subagentId;
    if (id == null) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final text = await showThreadTextDialog(
      context,
      title: l10n.thread_continue_dialog_title(
        entry.goal?.trim().isNotEmpty == true
            ? entry.goal!.trim()
            : l10n.thread_untitled,
      ),
      hint: l10n.thread_continue_dialog_hint,
      sendLabel: l10n.continue_label,
    );
    if (text == null) return;
    threads.rememberFinished(
      id: id,
      goal: entry.goal,
      status: entry.status,
      toolCount: entry.toolCount,
      durationSeconds: entry.durationSeconds,
      summary: entry.summary,
    );
    String notice;
    try {
      final result = await threads.continueThread(id, text);
      notice = switch (result.status) {
        ThreadContinueStatus.dispatched => l10n.thread_continue_started,
        ThreadContinueStatus.queued => l10n.thread_continue_queued,
        ThreadContinueStatus.rejected => l10n.thread_continue_rejected(
          result.error ?? '',
        ),
      };
    } catch (error) {
      notice = l10n.thread_continue_failed('$error');
    }
    messenger?.showSnackBar(SnackBar(content: Text(notice)));
  }

  Future<void> _reply(
    BuildContext context,
    ThreadMessageAnnotation message,
    String? preset,
  ) async {
    final questionId = message.questionId;
    if (questionId == null) return;
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.maybeOf(context);
    final goal = message.goal ?? threads.thread(message.subagentId)?.goal;
    final text =
        preset ??
        await showThreadTextDialog(
          context,
          title: l10n.thread_reply_dialog_title(
            goal?.trim().isNotEmpty == true
                ? goal!.trim()
                : l10n.thread_untitled,
          ),
          body: message.text,
          hint: l10n.thread_reply_hint,
          sendLabel: l10n.thread_reply,
        );
    if (text == null || text.trim().isEmpty) return;
    try {
      await threads.reply(
        subagentId: message.subagentId,
        questionId: questionId,
        text: text.trim(),
      );
    } on ThreadQuestionClosedException catch (closed) {
      // Someone else answered first, or the wait ended. The gateway's text
      // says which; the card now shows the question as closed.
      messenger?.showSnackBar(SnackBar(content: Text(closed.message)));
    } catch (error) {
      messenger?.showSnackBar(
        SnackBar(content: Text(l10n.thread_reply_failed('$error'))),
      );
    }
  }

  Future<void> _letCoordinatorDecide(
    BuildContext context,
    ThreadMessageAnnotation message,
  ) async {
    final questionId = message.questionId;
    if (questionId == null) return;
    threads.markCoordinatorDeciding(
      subagentId: message.subagentId,
      questionId: questionId,
    );
    var sent = false;
    try {
      sent = await sendCoordinatorPrompt(
        ThreadReplyWire.coordinatorDecidePrompt(message.subagentId),
      );
    } finally {
      if (!sent) threads.clearCoordinatorDeciding(questionId);
    }
  }

  @override
  void dispose() {
    _disposed = true;
    threads.dispose();
    super.dispose();
  }
}
