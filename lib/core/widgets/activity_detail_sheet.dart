import 'dart:convert';

import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/gateway_activity.dart';
import '../models/gateway_insight.dart';
import '../theme/hermes_theme.dart';
import '../utils/chat_display_items.dart';
import '../utils/message_content.dart';
import '../utils/tool_activity_summary.dart';
import 'activity_row.dart';
import 'markdown_code_block.dart';

/// Longest output excerpt the sheet shows.
const int kActivityOutputLimit = 4096;

/// What the detail sheet shows for one tool call, read when the sheet opens
/// (D8). Fields the app does not have stay `null` and their sections are
/// left out.
class ActivityCallDetail {
  const ActivityCallDetail({
    required this.activity,
    this.command,
    this.arguments,
    this.detail,
    this.output,
    this.outputTruncated = false,
  });

  final GatewayToolActivity activity;

  /// The shell command or code the call ran.
  final String? command;

  /// The call's other arguments as JSON, with secret-looking values hidden.
  final String? arguments;

  /// A live call's detail line when it is not a command (an error, a result
  /// note).
  final String? detail;

  /// The start of the stored output, at most [kActivityOutputLimit] long.
  final String? output;
  final bool outputTruncated;

  /// Reads the detail for [step] from the data the chat already holds: the
  /// activity itself, the stored tool-result row it was matched to, and the
  /// assistant message in [messages] whose tool call started it.
  factory ActivityCallDetail.resolve(
    ChatActivityStep step,
    List<Map<String, dynamic>> messages,
  ) {
    final activity = step.activity!;
    final kind = activityKindOf(activity.name);
    final args = _storedArgs(activity, step.storedRow, messages);

    String? command;
    if (args != null) {
      final raw = kind == ActivityKind.code || activity.name == 'browser_exec'
          ? args['code']
          : args['command'];
      if (raw is String && raw.trim().isNotEmpty) command = raw.trim();
    }
    String? detail;
    final liveDetail = activity.detail?.trim();
    if (command == null && liveDetail != null && liveDetail.isNotEmpty) {
      if (kind == ActivityKind.command && !activity.isFailed) {
        command = liveDetail;
      } else {
        detail = liveDetail;
      }
    }

    String? arguments;
    if (command == null && args != null && args.isNotEmpty) {
      arguments = const JsonEncoder.withIndent('  ').convert({
        for (final entry in args.entries)
          entry.key: isSensitiveToolArgKey(entry.key) ? '•••' : entry.value,
      });
    }

    String? output;
    var truncated = false;
    final row = step.storedRow;
    if (row != null) {
      final text = messageContentToText(row['content']).trim();
      if (text.isNotEmpty) {
        truncated = text.length > kActivityOutputLimit;
        output = truncated ? text.substring(0, kActivityOutputLimit) : text;
      }
    }

    return ActivityCallDetail(
      activity: activity,
      command: command,
      arguments: arguments,
      detail: detail,
      output: output,
      outputTruncated: truncated,
    );
  }

  static Map<String, dynamic>? _storedArgs(
    GatewayToolActivity activity,
    Map<String, dynamic>? row,
    List<Map<String, dynamic>> messages,
  ) {
    final rowArgs = _asArgs(row?['args']);
    if (rowArgs != null) return rowArgs;
    final toolId =
        activity.toolId ?? (row?['tool_call_id'] as String?)?.trim() ?? '';
    if (toolId.isEmpty) return null;
    for (final message in messages.reversed) {
      final calls = message['tool_calls'];
      if (calls is! List) continue;
      for (final call in calls) {
        if (call is! Map || call['id']?.toString() != toolId) continue;
        final function = call['function'];
        return _asArgs(function is Map ? function['arguments'] : null) ??
            _asArgs(call['arguments']) ??
            _asArgs(call['args']);
      }
    }
    return null;
  }

  static Map<String, dynamic>? _asArgs(dynamic value) {
    if (value is Map) return value.cast<String, dynamic>();
    if (value is String && value.trim().startsWith('{')) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) return decoded.cast<String, dynamic>();
      } on FormatException {
        return null;
      }
    }
    return null;
  }
}

/// Opens the detail sheet for one activity row.
///
/// Pass [step] for a tool call or a reasoning row, or [group] for a grouped
/// row. [messages] is the chat's current message list, read once here.
Future<void> showActivityDetailSheet(
  BuildContext context, {
  ChatActivityStep? step,
  ChatActivityGroupItem? group,
  GatewayNotice? notice,
  required List<Map<String, dynamic>> messages,
}) {
  assert(
    [step != null, group != null, notice != null].where((b) => b).length == 1,
  );
  final Widget body;
  if (notice != null) {
    body = ActivityDetailSheet.notice(notice);
  } else if (group != null) {
    body = ActivityDetailSheet.group([
      for (final item in group.steps)
        ActivityCallDetail.resolve(item, messages),
    ]);
  } else if (step!.isReasoning) {
    body = ActivityDetailSheet.reasoning(step.reasoning!);
  } else {
    body = ActivityDetailSheet.call(ActivityCallDetail.resolve(step, messages));
  }
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) => SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.8,
        ),
        child: body,
      ),
    ),
  );
}

String _clock(DateTime instant) {
  final local = instant.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}

String _seconds(double value) {
  if (value < 1) return '${(value * 1000).round()} ms';
  return '${value.toStringAsFixed(value < 10 ? 1 : 0)} s';
}

String _statusText(BuildContext context, GatewayToolActivity activity) {
  final l10n = context.l10n;
  final duration = activity.durationSeconds == null
      ? null
      : _seconds(activity.durationSeconds!);
  if (activity.isFailed) {
    return duration == null
        ? l10n.activity_state_failed
        : l10n.activity_failed_after(duration);
  }
  if (activity.isTerminal) {
    return duration == null
        ? l10n.activity_state_completed
        : l10n.activity_completed_in(duration);
  }
  return l10n.activity_state_running;
}

/// The body of the activity detail sheet: one tool call, a group of calls,
/// or a block of reasoning.
class ActivityDetailSheet extends StatelessWidget {
  const ActivityDetailSheet.call(ActivityCallDetail detail, {super.key})
    : _calls = const [],
      _call = detail,
      _reasoning = null,
      _notice = null;

  const ActivityDetailSheet.group(List<ActivityCallDetail> details, {super.key})
    : _calls = details,
      _call = null,
      _reasoning = null,
      _notice = null;

  const ActivityDetailSheet.reasoning(String text, {super.key})
    : _calls = const [],
      _call = null,
      _reasoning = text,
      _notice = null;

  const ActivityDetailSheet.notice(GatewayNotice notice, {super.key})
    : _calls = const [],
      _call = null,
      _reasoning = null,
      _notice = notice;

  final ActivityCallDetail? _call;
  final List<ActivityCallDetail> _calls;
  final String? _reasoning;
  final GatewayNotice? _notice;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final String title;
    final List<Widget> children;
    if (_reasoning != null) {
      title = l10n.reasoning;
      children = [
        SelectionArea(
          child: Text(_reasoning, style: theme.textTheme.bodyLarge),
        ),
      ];
    } else if (_notice != null) {
      final notice = _notice;
      title = notice.title;
      children = [
        Row(
          children: [
            Icon(
              notice.kind == GatewayNoticeKind.review
                  ? Icons.fact_check_outlined
                  : Icons.task_alt_outlined,
              size: 18,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Notice',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: HermesTokens.of(context).muted,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: HermesSpacing.md),
        SelectionArea(
          child: Text(notice.text, style: theme.textTheme.bodyLarge),
        ),
      ];
    } else if (_call != null) {
      title = _call.activity.displayName;
      children = _callBody(context, _call);
    } else {
      final first = _calls.first.activity;
      title = activityKindOf(first.name) == ActivityKind.command
          ? l10n.activity_sheet_command_executions
          : first.displayName;
      children = [for (final call in _calls) _GroupEntry(call)];
    }
    return ListView(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(
        HermesSpacing.xl,
        0,
        HermesSpacing.xl,
        HermesSpacing.xl,
      ),
      children: [
        Semantics(
          header: true,
          child: Text(title, style: theme.textTheme.titleLarge),
        ),
        const SizedBox(height: HermesSpacing.md),
        ...children,
      ],
    );
  }

  List<Widget> _callBody(BuildContext context, ActivityCallDetail call) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tokens = HermesTokens.of(context);
    final activity = call.activity;
    final at = activity.lastActivityAt;

    Widget heading(String text) => Padding(
      padding: const EdgeInsets.only(top: HermesSpacing.md),
      child: Text(text, style: theme.textTheme.labelLarge),
    );

    return [
      Row(
        children: [
          _StatusIcon(activity, size: 18),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              [
                _statusText(context, activity),
                if (at != null) _clock(at),
              ].join(' · '),
              style: theme.textTheme.labelMedium?.copyWith(color: tokens.muted),
            ),
          ),
        ],
      ),
      // A call with no summary would only repeat the sheet's title here.
      if (activitySummaryLine(activity) != activity.displayName) ...[
        const SizedBox(height: HermesSpacing.md),
        Text(activitySummaryLine(activity), style: theme.textTheme.bodyLarge),
      ],
      if (call.command != null) ...[
        heading(l10n.command),
        MarkdownCodeBlock(
          code: call.command!,
          language: activityKindOf(activity.name) == ActivityKind.command
              ? 'bash'
              : null,
        ),
      ],
      if (call.arguments != null) ...[
        heading(l10n.activity_sheet_arguments),
        MarkdownCodeBlock(code: call.arguments!, language: 'json'),
      ],
      if (call.detail != null) ...[
        heading(l10n.activity_sheet_details),
        MarkdownCodeBlock(code: call.detail!, language: 'text'),
      ],
      if (call.output != null) ...[
        heading(l10n.activity_sheet_output),
        MarkdownCodeBlock(code: call.output!, language: 'text'),
        if (call.outputTruncated)
          Text(
            l10n.activity_sheet_output_truncated,
            style: theme.textTheme.bodySmall?.copyWith(color: tokens.muted),
          ),
      ],
    ];
  }
}

class _StatusIcon extends StatelessWidget {
  const _StatusIcon(this.activity, {required this.size});

  final GatewayToolActivity activity;
  final double size;

  @override
  Widget build(BuildContext context) {
    final tokens = HermesTokens.of(context);
    if (!activity.isTerminal) {
      return SizedBox.square(
        dimension: size,
        child: const Padding(
          padding: EdgeInsets.all(2),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return Icon(
      activity.isFailed ? Icons.error_outline : Icons.check_circle_outline,
      size: size,
      color: activity.isFailed ? tokens.danger : tokens.success,
    );
  }
}

/// One call in a group sheet: its summary, how long it took, and its command.
class _GroupEntry extends StatelessWidget {
  const _GroupEntry(this.call);

  final ActivityCallDetail call;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tokens = HermesTokens.of(context);
    final activity = call.activity;
    final code = call.command ?? call.arguments ?? call.detail;
    return Padding(
      padding: const EdgeInsets.only(bottom: HermesSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _StatusIcon(activity, size: 16),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  activitySummaryLine(activity),
                  style: theme.textTheme.bodyMedium,
                ),
              ),
              if (activity.durationSeconds != null)
                Text(
                  _seconds(activity.durationSeconds!),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: tokens.muted,
                  ),
                ),
            ],
          ),
          if (code != null)
            MarkdownCodeBlock(
              code: code,
              language: call.command == null
                  ? (call.arguments == null ? 'text' : 'json')
                  : activityKindOf(activity.name) == ActivityKind.command
                  ? 'bash'
                  : null,
            ),
        ],
      ),
    );
  }
}
