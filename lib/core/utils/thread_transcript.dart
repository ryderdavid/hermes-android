import 'dart:convert';

import '../models/gateway_activity.dart';
import '../services/thread_wire.dart';
import 'chat_display_items.dart';
import 'message_content.dart';
import 'tool_activity_summary.dart';

/// What a thread did, in the shape the chat's display projection takes: a
/// message list and the tool calls that belong to it.
class ThreadTranscript {
  const ThreadTranscript({
    this.messages = const [],
    this.activities = const [],
    this.task,
  });

  static const empty = ThreadTranscript();

  /// Stored rows, or rows rebuilt from a live tail. The first user message,
  /// when present, is the task the coordinator gave the thread.
  final List<Map<String, dynamic>> messages;
  final List<GatewayToolActivity> activities;

  /// The task text, when the transcript carries it.
  final String? task;

  bool get isEmpty =>
      activities.isEmpty &&
      !messages.any((message) => message[taskMarker] != true);

  /// Marks the message that holds the task rather than something to show as
  /// a bubble.
  static const taskMarker = '_thread_task';

  /// The chat's display items for this transcript.
  ///
  /// [running] shows every step as its own row. A finished transcript folds
  /// each turn's steps behind its "Worked for…" line, unfolded unless
  /// [foldChoice] says otherwise: the thread view exists to show the work.
  List<dynamic> displayItems({
    required bool running,
    bool? Function(String turnId)? foldChoice,
  }) => buildChatDisplayItems(
    messages: messages,
    toolActivities: activities,
    turnActive: running,
    foldChoice: (turnId) => foldChoice?.call(turnId) ?? true,
  );

  /// A transcript from the child session's stored rows.
  factory ThreadTranscript.fromHistory(List<Map<String, dynamic>> rows) {
    final messages = [for (final row in rows) Map<String, dynamic>.from(row)];
    String? task;
    for (final message in messages) {
      if (message['role'] != 'user' || isToolResultMessage(message)) continue;
      final text = messageContentToText(message['content']).trim();
      if (text.isEmpty) continue;
      message[taskMarker] = true;
      task = text;
      break;
    }
    return ThreadTranscript(
      messages: messages,
      activities: toolActivitiesFromStoredMessages(messages),
      task: task,
    );
  }

  /// A transcript from a live tail (`subagent.tail`).
  ///
  /// The tail is the last 16 KB of an operational log: one line per event,
  /// each cut to a few hundred characters. [fallbackTask] stands in for the
  /// kickoff line when the window no longer reaches back to it.
  factory ThreadTranscript.fromTail(
    List<ThreadTailLine> lines, {
    String? fallbackTask,
  }) {
    String? task;
    final messages = <Map<String, dynamic>>[];
    final activities = <GatewayToolActivity>[];

    // The projection anchors a live tool call to the message before it, so
    // the task always occupies index 0.
    void ensureTask() {
      if (messages.isNotEmpty) return;
      messages.add({
        'role': 'user',
        'content': task ?? fallbackTask ?? '',
        taskMarker: true,
      });
    }

    for (final (index, line) in lines.indexed) {
      switch (line.role) {
        case 'user':
          if (messages.isEmpty) {
            var text = line.text;
            if (text.startsWith('kickoff: ')) {
              text = text.substring('kickoff: '.length);
            }
            task = text;
          }
          ensureTask();
        case 'assistant':
          ensureTask();
          messages.add({
            'role': 'assistant',
            'content': line.text,
            '_gateway_interim': true,
          });
        case 'think':
          ensureTask();
          messages.add({
            'role': 'assistant',
            'content': '',
            '_gateway_reasoning': line.text,
          });
        case 'tool':
          final start = line.toolStart;
          if (start == null) continue;
          ensureTask();
          activities.add(
            GatewayToolActivity(
              name: start.name,
              phase: GatewayToolActivityPhase.running,
              identity: 'tail:$index',
              summary: _tailSummary(start.name, start.args),
              detail: start.args.isEmpty ? null : start.args,
              anchorMessageIndex: messages.length - 1,
            ),
          );
        case 'result':
          final result = line.toolResult;
          if (result == null) continue;
          final open = activities.lastIndexWhere(
            (activity) =>
                !activity.isTerminal &&
                activity.name.toLowerCase() == result.name.toLowerCase(),
          );
          if (open < 0) continue;
          final started = activities[open];
          activities[open] = GatewayToolActivity(
            name: started.name,
            phase: result.isError
                ? GatewayToolActivityPhase.failed
                : GatewayToolActivityPhase.completed,
            identity: started.identity,
            summary: started.summary,
            detail: result.isError && result.result.isNotEmpty
                ? result.result
                : started.detail,
            durationSeconds: result.seconds,
            anchorMessageIndex: started.anchorMessageIndex,
          );
      }
    }
    if (lines.isNotEmpty) ensureTask();
    return ThreadTranscript(
      messages: messages,
      activities: activities,
      task: task ?? fallbackTask,
    );
  }

  static String? _tailSummary(String name, String args) {
    if (args.isEmpty) return null;
    if (args.startsWith('{')) {
      try {
        final decoded = jsonDecode(args);
        if (decoded is Map) {
          final summary = toolActivitySummary(
            name,
            decoded.cast<String, dynamic>(),
          );
          if (summary != null) return summary;
        }
      } on FormatException {
        // A preview cut mid-way is not JSON; fall through to the raw text.
      }
    }
    return previewSummary(
      name,
      args.length <= 120 ? args : '${args.substring(0, 119)}…',
    );
  }
}

/// One tool activity per stored tool-result row, in order: the same reading
/// of history the main chat uses for its activity rows.
List<GatewayToolActivity> toolActivitiesFromStoredMessages(
  List<Map<String, dynamic>> messages,
) {
  final activities = <GatewayToolActivity>[];
  for (final message in messages) {
    if (!isToolResultMessage(message)) continue;
    final name =
        (message['name'] as String?) ??
        (message['tool_name'] as String?) ??
        (message['toolCallName'] as String?) ??
        '';
    final toolCallId = (message['tool_call_id'] as String?) ?? '';
    var toolName = name;
    if (toolName.isEmpty) {
      final content = messageContentToText(message['content']);
      toolName =
          RegExp(r'source="([^"]+)"').firstMatch(content)?.group(1) ?? '';
    }
    activities.add(
      GatewayToolActivity.fromStoredResult(
        toolId: toolCallId.isEmpty ? null : toolCallId,
        name: toolName.isEmpty ? 'tool' : toolName,
        timestamp: message['timestamp'],
        args: message['args'] is Map
            ? (message['args'] as Map).cast<String, dynamic>()
            : null,
        contextPreview: message['context'] is String
            ? message['context'] as String
            : null,
      ),
    );
  }
  return activities;
}
