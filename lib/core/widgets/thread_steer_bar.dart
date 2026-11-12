import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/agent_thread.dart';
import '../services/agent_threads_controller.dart';
import '../services/thread_wire.dart';
import '../theme/hermes_theme.dart';

/// The bar at the foot of a thread view.
///
/// While the thread runs it steers (text only, delivered at the thread's
/// next step) and stops that thread. Once the thread has finished, and the
/// gateway can continue threads, the same field sends a follow-up. It is its
/// own control, not a mode of the chat composer: no attachments, voice or
/// model picker.
class ThreadSteerBar extends StatefulWidget {
  const ThreadSteerBar({
    required this.controller,
    required this.threadId,
    super.key,
  });

  final AgentThreadsController controller;
  final String threadId;

  @override
  State<ThreadSteerBar> createState() => _ThreadSteerBarState();
}

class _ThreadSteerBarState extends State<ThreadSteerBar> {
  final _text = TextEditingController();
  bool _busy = false;
  String? _notice;
  bool _noticeIsError = false;
  ThreadSteerStatus? _lastSteerStatus;

  AgentThreadsController get _controller => widget.controller;

  @override
  void initState() {
    super.initState();
    _text.addListener(_onTextChanged);
    _controller.addListener(_onThreadsChanged);
    _lastSteerStatus = _controller.steerRecord(widget.threadId)?.status;
  }

  @override
  void dispose() {
    _controller.removeListener(_onThreadsChanged);
    _text.dispose();
    super.dispose();
  }

  void _onTextChanged() => setState(() {});

  void _onThreadsChanged() {
    final record = _controller.steerRecord(widget.threadId);
    if (record?.status != _lastSteerStatus) {
      _lastSteerStatus = record?.status;
      // A steer that did not land comes back into the field, so it can be
      // sent as a follow-up. Text the user typed since is left alone.
      if (record?.status == ThreadSteerStatus.didNotLand &&
          _text.text.trim().isEmpty) {
        _text.text = record!.text;
        _text.selection = TextSelection.collapsed(offset: _text.text.length);
      }
    }
    if (mounted) setState(() {});
  }

  void _setNotice(String? text, {bool error = false}) {
    if (!mounted) return;
    setState(() {
      _notice = text;
      _noticeIsError = error;
    });
  }

  Future<void> _steer() async {
    final text = _text.text.trim();
    if (text.isEmpty || _busy) return;
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final record = await _controller.steer(widget.threadId, text);
      if (!mounted) return;
      // Only text the gateway took leaves the field.
      if (record.status == ThreadSteerStatus.sent &&
          _text.text.trim() == text) {
        _text.clear();
      }
    } catch (error) {
      _setNotice(l10n.thread_steer_failed('$error'), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    if (_busy) return;
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final found = await _controller.stop(widget.threadId);
      if (!found) _setNotice(l10n.threads_already_finished);
    } catch (error) {
      _setNotice(l10n.threads_action_failed('$error'), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _continue() async {
    final text = _text.text.trim();
    if (text.isEmpty || _busy) return;
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _notice = null;
    });
    try {
      final result = await _controller.continueThread(widget.threadId, text);
      if (!mounted) return;
      switch (result.status) {
        case ThreadContinueStatus.dispatched:
          _text.clear();
          _controller.clearSteer(widget.threadId);
          _setNotice(l10n.thread_continue_started);
        case ThreadContinueStatus.queued:
          _text.clear();
          _controller.clearSteer(widget.threadId);
          _setNotice(l10n.thread_continue_queued);
        case ThreadContinueStatus.rejected:
          _setNotice(
            l10n.thread_continue_rejected(result.error ?? ''),
            error: true,
          );
      }
    } catch (error) {
      _setNotice(l10n.thread_continue_failed('$error'), error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tokens = HermesTokens.of(context);
    final thread = _controller.thread(widget.threadId);
    if (thread == null) return const SizedBox.shrink();
    final support = _controller.support;
    final live = thread.state.isLive;
    final queued = thread.state == AgentThreadState.queued;
    final canContinue = thread.state.isFinished && support.continueThreads;
    final steerRecord = _controller.steerRecord(widget.threadId);
    final hasText = _text.text.trim().isNotEmpty;

    // What the field can do right now, and why not when it cannot.
    final bool fieldEnabled;
    String? explanation;
    if (live) {
      if (!support.steer) {
        fieldEnabled = false;
        explanation = l10n.thread_steer_unavailable_gateway;
      } else if (thread.acceptingSteer == false) {
        fieldEnabled = false;
        explanation = l10n.thread_steer_unsupported;
      } else {
        fieldEnabled = true;
      }
    } else if (canContinue) {
      fieldEnabled = true;
    } else {
      fieldEnabled = false;
    }

    final steerNotice = switch (steerRecord?.status) {
      ThreadSteerStatus.sent => l10n.thread_steer_sent,
      ThreadSteerStatus.acknowledged => l10n.thread_steer_acknowledged,
      ThreadSteerStatus.didNotLand => l10n.thread_steer_did_not_land,
      _ => null,
    };
    final queueNotice = queued
        ? switch (_controller.queuePosition(thread.id)) {
            final position? =>
              '${l10n.thread_queued_waiting} · '
                  '${l10n.thread_queue_position(position)}',
            null => l10n.thread_queued_waiting,
          }
        : null;
    final status = _notice ?? explanation ?? queueNotice ?? steerNotice;
    final statusIsError = _notice != null
        ? _noticeIsError
        : explanation == null &&
              queueNotice == null &&
              steerRecord?.status == ThreadSteerStatus.didNotLand;

    // A finished thread that cannot be continued has nothing to send to.
    // The bar stays only to say what became of a steer and to hold its text.
    final showField = live || canContinue || (!queued && hasText);
    if (!showField && status == null) return const SizedBox.shrink();

    return Material(
      key: const Key('thread-steer-bar'),
      color: scheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (status != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      status,
                      key: const Key('thread-steer-status'),
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: statusIsError ? tokens.danger : tokens.muted,
                      ),
                    ),
                  ),
                ),
              if (showField)
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const Key('thread-steer-field'),
                        controller: _text,
                        enabled: fieldEnabled && !_busy,
                        minLines: 1,
                        maxLines: 4,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: InputDecoration(
                          hintText: live
                              ? l10n.thread_steer_hint
                              : l10n.thread_follow_up_hint,
                          prefixIcon: Icon(
                            live ? Icons.alt_route : Icons.reply,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (live)
                      IconButton.filled(
                        key: const Key('thread-steer-send'),
                        onPressed: fieldEnabled && hasText && !_busy
                            ? _steer
                            : null,
                        icon: const Icon(Icons.arrow_upward),
                        tooltip: l10n.thread_steer_send,
                      )
                    else if (canContinue)
                      IconButton.filled(
                        key: const Key('thread-continue-send'),
                        onPressed: hasText && !_busy ? _continue : null,
                        icon: const Icon(Icons.arrow_upward),
                        tooltip: l10n.thread_follow_up_send,
                      ),
                    if (live && support.steer)
                      IconButton.filledTonal(
                        key: const Key('thread-stop'),
                        onPressed: _busy ? null : _stop,
                        icon: const Icon(Icons.stop),
                        tooltip: l10n.threads_stop_tooltip,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
