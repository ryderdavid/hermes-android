import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../models/gateway_activity.dart';
import '../models/gateway_insight.dart';
import '../theme/hermes_theme.dart';

/// The broad kind of a tool, which picks a row's icon and a group's label.
enum ActivityKind { command, read, edit, search, web, browser, code, other }

ActivityKind activityKindOf(String toolName) {
  final name = toolName.toLowerCase();
  switch (name) {
    case 'terminal':
    case 'shell':
    case 'execute':
      return ActivityKind.command;
    case 'read_file':
    case 'read':
      return ActivityKind.read;
    case 'write_file':
    case 'write':
    case 'patch':
      return ActivityKind.edit;
    case 'search_files':
    case 'search':
    case 'session_search':
      return ActivityKind.search;
    case 'web_search':
    case 'web_extract':
    case 'google_search':
      return ActivityKind.web;
    case 'execute_code':
      return ActivityKind.code;
  }
  if (name.startsWith('browser')) return ActivityKind.browser;
  return ActivityKind.other;
}

IconData activityIconFor(String toolName) => switch (activityKindOf(toolName)) {
  ActivityKind.command => Icons.terminal,
  ActivityKind.read => Icons.description_outlined,
  ActivityKind.edit => Icons.edit_note,
  ActivityKind.search => Icons.manage_search,
  ActivityKind.web => Icons.travel_explore,
  ActivityKind.browser => Icons.public,
  ActivityKind.code => Icons.code,
  ActivityKind.other => Icons.build_outlined,
};

const IconData activityReasoningIcon = Icons.psychology_outlined;

/// Tools whose summary is already a sentence about what the call does
/// ("running the test suite"). Every other summary is the thing the call acts
/// on (a path, a query), which only reads as a sentence after the tool name.
const _sentenceSummaryTools = {
  'terminal',
  'execute_code',
  'browser_exec',
  'delegate_task',
  'clarify',
};

/// What a tool call did, in one plain line, without its state.
String activitySummaryLine(GatewayToolActivity activity) {
  final summary = activity.summary;
  if (summary == null || summary.isEmpty) return activity.displayName;
  if (!_sentenceSummaryTools.contains(activity.name.toLowerCase())) {
    return activity.displayTitle;
  }
  return summary[0].toUpperCase() + summary.substring(1);
}

/// The label of a row that stands for [count] calls to [toolName].
String activityGroupLabel(BuildContext context, String toolName, int count) {
  final l10n = context.l10n;
  return switch (activityKindOf(toolName)) {
    ActivityKind.command => l10n.activity_group_commands(count),
    ActivityKind.read => l10n.activity_group_files_read(count),
    ActivityKind.edit => l10n.activity_group_files_edited(count),
    ActivityKind.search ||
    ActivityKind.web => l10n.activity_group_searches(count),
    _ => l10n.activity_group_generic(
      GatewayToolActivity.displayNameOf(toolName),
      count,
    ),
  };
}

enum ActivityRowState { running, completed, failed }

/// One line of agent activity in the chat: a tool call, a block of reasoning,
/// or a run of calls to the same tool.
///
/// The row is a fixed 48dp at the default text size and never expands in
/// place, so adding or updating one does not move the rows above it. Tapping
/// it calls [onTap], which the chat uses to open the detail sheet.
class ActivityRow extends StatelessWidget {
  /// A row built from explicit parts. Prefer the named constructors.
  const ActivityRow({
    required this.icon,
    required this.label,
    required this.kindLabel,
    this.state = ActivityRowState.completed,
    this.onTap,
    super.key,
  }) : activity = null,
       _groupCount = null,
       _reasoning = false;

  /// A single tool call.
  const ActivityRow.tool({
    required GatewayToolActivity this.activity,
    this.onTap,
    super.key,
  }) : _groupCount = null,
       _reasoning = false,
       icon = null,
       label = null,
       kindLabel = null,
       state = ActivityRowState.completed;

  /// A block of reasoning. [headline] is its first usable line, or `null` to
  /// show the generic "Thinking".
  const ActivityRow.reasoning({
    String? headline,
    bool running = false,
    this.onTap,
    super.key,
  }) : activity = null,
       _groupCount = null,
       _reasoning = true,
       icon = null,
       label = headline,
       kindLabel = null,
       state = running ? ActivityRowState.running : ActivityRowState.completed;

  /// A run of [count] successful calls to the tool named like [first].
  const ActivityRow.group({
    required GatewayToolActivity first,
    required int count,
    this.onTap,
    super.key,
  }) : activity = first,
       _groupCount = count,
       _reasoning = false,
       icon = null,
       label = null,
       kindLabel = null,
       state = ActivityRowState.completed;

  /// A gateway notice (Hermes review / background completion) as one line:
  /// title plus the notice text, ellipsized. Tapping opens the detail sheet.
  ActivityRow.notice({
    required GatewayNotice notice,
    this.onTap,
    super.key,
  }) : activity = null,
       _groupCount = null,
       _reasoning = false,
       icon = notice.kind == GatewayNoticeKind.review
           ? Icons.fact_check_outlined
           : Icons.task_alt_outlined,
       label = '${notice.title} — ${notice.text.replaceAll('\n', ' ')}',
       kindLabel = null,
       state = ActivityRowState.completed;

  static const double minHeight = 48;

  final IconData? icon;
  final String? label;

  /// The kind of activity, announced before the label by a screen reader.
  final String? kindLabel;
  final ActivityRowState state;
  final VoidCallback? onTap;

  /// The call a tool row shows, or the first call of a group row.
  final GatewayToolActivity? activity;
  final int? _groupCount;
  final bool _reasoning;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tokens = HermesTokens.of(context);
    final activity = this.activity;

    final IconData rowIcon;
    final String rowKind;
    final String summary;
    var rowState = state;
    if (_reasoning) {
      rowIcon = activityReasoningIcon;
      rowKind = l10n.reasoning;
      summary = label ?? l10n.activity_thinking;
    } else if (activity != null && _groupCount != null) {
      rowIcon = activityIconFor(activity.name);
      rowKind = activity.displayName;
      summary = activityGroupLabel(context, activity.name, _groupCount);
    } else if (activity != null) {
      rowIcon = activityIconFor(activity.name);
      rowKind = activity.displayName;
      summary = activitySummaryLine(activity);
      rowState = activity.isFailed
          ? ActivityRowState.failed
          : activity.isTerminal
          ? ActivityRowState.completed
          : ActivityRowState.running;
    } else {
      rowIcon = icon ?? Icons.build_outlined;
      rowKind = kindLabel ?? '';
      summary = label ?? '';
    }

    final failed = rowState == ActivityRowState.failed;
    final running = rowState == ActivityRowState.running;
    final text = failed ? l10n.activity_failed_label(summary) : summary;
    final color = failed
        ? tokens.danger
        : running
        ? theme.colorScheme.onSurface
        : tokens.muted;
    final stateLabel = switch (rowState) {
      ActivityRowState.running => l10n.activity_state_running,
      ActivityRowState.completed => l10n.activity_state_completed,
      ActivityRowState.failed => l10n.activity_state_failed,
    };

    return Semantics(
      container: true,
      button: true,
      excludeSemantics: true,
      label: [
        if (rowKind.isNotEmpty && rowKind != summary) rowKind,
        summary,
        stateLabel,
      ].join(', '),
      onTap: onTap,
      onTapHint: onTap == null ? null : l10n.activity_show_details,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: minHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(28, 0, 24, 0),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 20,
                  child: running
                      ? const Padding(
                          padding: EdgeInsets.all(3),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(
                          failed ? Icons.error_outline : rowIcon,
                          size: 20,
                          color: color,
                        ),
                ),
                const SizedBox(width: HermesSpacing.md),
                Expanded(
                  child: Text(
                    text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodyLarge?.copyWith(color: color),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
