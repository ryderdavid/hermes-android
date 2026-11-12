/// Wire shapes of the gateway's thread (background subagent) surface.
///
/// Every field name the app reads from, or sends to, the gateway for the
/// `coordinator-threads` change lives in this file, so it can be reconciled
/// against the gateway contract (`docs/coordinator-threads.md` in the
/// hermes-agent fork) in one place. Nothing here touches Flutter or a socket.
library;

import 'dart:convert';

/// RPC method names.
abstract final class ThreadRpc {
  /// Per-chat roster of live threads. Params: `session_id`.
  static const list = 'subagent.list';

  /// App-wide count per stored conversation; takes no `session_id`. Used only
  /// as the once-per-connection probe for thread support on stock gateways.
  static const roster = 'subagent.roster';
  static const tail = 'subagent.tail';
  static const steer = 'subagent.steer';
  static const interrupt = 'subagent.interrupt';
  static const reply = 'subagent.reply';
  static const continueThread = 'subagent.continue';
  static const delegationStatus = 'delegation.status';
  static const delegationPause = 'delegation.pause';
  static const sessionModeSet = 'session.mode.set';
}

/// Capability keys advertised in `session.info.capabilities`.
abstract final class ThreadCapabilityKey {
  static const roster = 'threads.roster';
  static const steer = 'threads.steer';
  static const messages = 'threads.messages';
  static const continueThreads = 'threads.continue';
  static const approvals = 'threads.approvals';
  static const coordinatorMode = 'coordinator_mode';

  static const all = {
    roster,
    steer,
    messages,
    continueThreads,
    approvals,
    coordinatorMode,
  };
}

/// Async event types the thread UI consumes.
abstract final class ThreadEventType {
  static const sessionInfo = 'session.info';
  static const spawnRequested = 'subagent.spawn_requested';
  static const start = 'subagent.start';
  static const thinking = 'subagent.thinking';
  static const tool = 'subagent.tool';
  static const progress = 'subagent.progress';
  static const complete = 'subagent.complete';

  /// A thread update or question was delivered as a parent turn.
  static const message = 'subagent.message';

  /// Question lifecycle: pending, answered, expired, cancelled.
  static const question = 'subagent.question';
}

/// `display_kind` values of the parent turns threads create.
abstract final class ThreadDisplayKind {
  static const message = 'async_delegation_message';
  static const complete = 'async_delegation_complete';
}

String? _text(Object? value, {int max = 4000}) {
  if (value == null) return null;
  final text = value.toString().replaceAll('\u0000', '').trim();
  if (text.isEmpty) return null;
  return text.length <= max ? text : text.substring(0, max);
}

int? _int(Object? value) => switch (value) {
  final int v => v,
  final num v => v.toInt(),
  final String v => int.tryParse(v),
  _ => null,
};

double? _double(Object? value) => switch (value) {
  final num v => v.toDouble(),
  final String v => double.tryParse(v),
  _ => null,
};

/// Gateway times are epoch seconds.
DateTime? _epoch(Object? value) {
  final seconds = _double(value);
  if (seconds == null || seconds <= 0) return null;
  return DateTime.fromMillisecondsSinceEpoch(
    (seconds * 1000).round(),
    isUtc: true,
  );
}

Map<String, dynamic>? _map(Object? value) {
  if (value is Map) {
    return {
      for (final entry in value.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
  }
  if (value is String && value.trimLeft().startsWith('{')) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) return _map(decoded);
    } catch (_) {
      // Not JSON: treated as absent.
    }
  }
  return null;
}

List<Map<String, dynamic>> _maps(Object? value) => [
  if (value is List)
    for (final item in value) ?_map(item),
];

List<String> _strings(Object? value) => [
  if (value is List)
    for (final item in value) ?_text(item, max: 400),
];

/// The `capabilities` and `coordinator_mode` fields of a `session.info`
/// object (the event payload, or `info` of a session.create/resume result).
class ThreadSessionInfo {
  const ThreadSessionInfo({required this.capabilities, this.coordinatorMode});

  /// Capability keys this gateway advertised. Empty on a stock gateway.
  final Set<String> capabilities;

  /// The session's stored coordinator flag, when the gateway reports one.
  final bool? coordinatorMode;

  /// `null` when [info] is not a session.info object at all.
  static ThreadSessionInfo? parse(Object? info) {
    final map = _map(info);
    if (map == null) return null;
    final raw = map['capabilities'];
    return ThreadSessionInfo(
      capabilities: {
        if (raw is List)
          for (final item in raw)
            if (item is String && item.isNotEmpty) item,
      },
      coordinatorMode: map['coordinator_mode'] is bool
          ? map['coordinator_mode'] as bool
          : null,
    );
  }
}

/// A question a thread is waiting on (`pending_question` on a roster row, or
/// a `subagent.question` event with `status: pending`).
class ThreadQuestionWire {
  const ThreadQuestionWire({
    required this.questionId,
    required this.text,
    this.options = const [],
    this.askedAt,
    this.expiresAt,
  });

  final String questionId;
  final String text;
  final List<String> options;
  final DateTime? askedAt;
  final DateTime? expiresAt;

  static ThreadQuestionWire? parse(Object? value) {
    final map = _map(value);
    final id = _text(map?['question_id'], max: 200);
    if (map == null || id == null) return null;
    return ThreadQuestionWire(
      questionId: id,
      text: _text(map['text']) ?? '',
      options: _strings(map['options']),
      askedAt: _epoch(map['asked_at']),
      expiresAt: _epoch(map['expires_at']),
    );
  }
}

/// One row of `subagent.list` → `subagents` (also a `delegation.status`
/// `active` row, which carries the same fields).
class ThreadRosterRow {
  const ThreadRosterRow({
    required this.subagentId,
    this.parentId,
    this.depth,
    this.goal,
    this.delegationId,
    this.model,
    this.startedAt,
    this.status,
    this.toolCount,
    this.lastTool,
    this.acceptingSteer,
    this.childSessionId,
    this.pendingQuestion,
  });

  final String subagentId;
  final String? parentId;
  final int? depth;
  final String? goal;
  final String? delegationId;
  final String? model;
  final DateTime? startedAt;
  final String? status;
  final int? toolCount;
  final String? lastTool;
  final bool? acceptingSteer;
  final String? childSessionId;
  final ThreadQuestionWire? pendingQuestion;

  static ThreadRosterRow? parse(Object? value) {
    final map = _map(value);
    final id = _text(map?['subagent_id'], max: 200);
    if (map == null || id == null) return null;
    return ThreadRosterRow(
      subagentId: id,
      parentId: _text(map['parent_id'], max: 200),
      depth: _int(map['depth']),
      goal: _text(map['goal'], max: 500),
      delegationId: _text(map['delegation_id'], max: 200),
      model: _text(map['model'], max: 200),
      startedAt: _epoch(map['started_at']),
      status: _text(map['status'], max: 40)?.toLowerCase(),
      toolCount: _int(map['tool_count']),
      lastTool: _text(map['last_tool'], max: 120),
      acceptingSteer: map['accepting_steer'] is bool
          ? map['accepting_steer'] as bool
          : null,
      childSessionId: _text(map['child_session_id'], max: 200),
      pendingQuestion: ThreadQuestionWire.parse(map['pending_question']),
    );
  }
}

/// One row of `subagent.list` → `delegations`: a recently failed task.
class ThreadFailedDelegation {
  const ThreadFailedDelegation({
    required this.delegationId,
    required this.taskIndex,
    required this.status,
    this.goal,
    this.error,
    this.completedAt,
  });

  final String delegationId;
  final int taskIndex;
  final String status;
  final String? goal;
  final String? error;
  final DateTime? completedAt;

  static ThreadFailedDelegation? parse(Object? value) {
    final map = _map(value);
    final id = _text(map?['delegation_id'], max: 200);
    if (map == null || id == null) return null;
    return ThreadFailedDelegation(
      delegationId: id,
      taskIndex: _int(map['task_index']) ?? 0,
      status: _text(map['status'], max: 40)?.toLowerCase() ?? 'failed',
      goal: _text(map['goal'], max: 500),
      error: _text(map['error'], max: 1000),
      completedAt: _epoch(map['completed_at']),
    );
  }
}

/// One row of `subagent.list` → `queued`: a follow-up waiting for a slot.
class ThreadQueuedRow {
  const ThreadQueuedRow({required this.subagentId, this.goal, this.queuedAt});

  final String subagentId;
  final String? goal;
  final DateTime? queuedAt;

  static ThreadQueuedRow? parse(Object? value) {
    final map = _map(value);
    final id = _text(map?['subagent_id'], max: 200);
    if (map == null || id == null) return null;
    return ThreadQueuedRow(
      subagentId: id,
      goal: _text(map['goal'], max: 500),
      queuedAt: _epoch(map['queued_at']),
    );
  }
}

/// The `subagent.list` result.
class ThreadRosterSnapshot {
  const ThreadRosterSnapshot({
    this.threads = const [],
    this.failed = const [],
    this.queued = const [],
  });

  final List<ThreadRosterRow> threads;
  final List<ThreadFailedDelegation> failed;
  final List<ThreadQueuedRow> queued;

  factory ThreadRosterSnapshot.parse(
    Map<String, dynamic> result,
  ) => ThreadRosterSnapshot(
    threads: [
      for (final row in _maps(result['subagents'])) ?ThreadRosterRow.parse(row),
    ],
    failed: [
      for (final row in _maps(result['delegations']))
        ?ThreadFailedDelegation.parse(row),
    ],
    queued: [
      for (final row in _maps(result['queued'])) ?ThreadQueuedRow.parse(row),
    ],
  );
}

/// The `delegation.status` result. Gateway-wide, not per chat.
class DelegationStatusSnapshot {
  const DelegationStatusSnapshot({
    required this.activeCount,
    required this.paused,
    this.maxConcurrent,
    this.model,
  });

  /// Top-level threads running on the gateway: the background slots in use.
  final int activeCount;
  final bool paused;

  /// `max_concurrent_children`: the background slot limit.
  final int? maxConcurrent;

  /// The model of the first active thread, shown next to the slot count.
  final String? model;

  factory DelegationStatusSnapshot.parse(Map<String, dynamic> result) {
    final active = [
      for (final row in _maps(result['active'])) ?ThreadRosterRow.parse(row),
    ];
    final topLevel = active.where((row) => (row.depth ?? 0) == 0).toList();
    return DelegationStatusSnapshot(
      activeCount: topLevel.length,
      paused: result['paused'] == true,
      maxConcurrent: _int(result['max_concurrent_children']),
      model: topLevel.isEmpty ? null : topLevel.first.model,
    );
  }
}

/// The `subagent.tail` result: the last 16 KB of a live thread's transcript.
class ThreadTailSnapshot {
  const ThreadTailSnapshot({
    required this.available,
    this.text = '',
    this.truncated = false,
  });

  /// False while the thread has no live transcript (not started, or ended).
  final bool available;
  final String text;

  /// True when the transcript is longer than the returned tail.
  final bool truncated;

  factory ThreadTailSnapshot.parse(Map<String, dynamic> result) =>
      ThreadTailSnapshot(
        available: result['available'] == true,
        text: result['text'] is String ? result['text'] as String : '',
        truncated: result['truncated'] == true,
      );
}

/// One line of a live transcript: `HH:MM:SS role     | text`.
class ThreadTailLine {
  const ThreadTailLine({required this.role, required this.text, this.time});

  /// `user`, `start`, `assistant`, `think`, `tool`, `result` or `final`.
  final String role;
  final String text;

  /// The wall-clock time the gateway wrote, as `HH:MM:SS`.
  final String? time;

  static final _line = RegExp(r'^(\d{2}:\d{2}:\d{2}) (\S+)\s*\| ?(.*)$');

  /// Parses a tail. Header lines and a first line cut mid-way by the 16 KB
  /// window are dropped.
  static List<ThreadTailLine> parseAll(String text) => [
    for (final raw in const LineSplitter().convert(text))
      if (_line.firstMatch(raw) case final match?)
        ThreadTailLine(
          time: match.group(1),
          role: match.group(2)!.toLowerCase(),
          text: match.group(3)!.trim(),
        ),
  ];

  static final _toolStart = RegExp(r'^->\s*([^\s(]+)\((.*)\)$', dotAll: true);
  static final _toolResult = RegExp(
    r'^(\S+) (ok|ERROR)(?: (\d+(?:\.\d+)?)s)?: ?(.*)$',
    dotAll: true,
  );

  /// For a `tool` line: the tool name and its argument preview.
  ({String name, String args})? get toolStart {
    final match = _toolStart.firstMatch(text);
    if (match == null) return null;
    return (name: match.group(1)!, args: match.group(2)!.trim());
  }

  /// For a `result` line: the tool name, outcome, duration and result text.
  ({String name, bool isError, double? seconds, String result})?
  get toolResult {
    final match = _toolResult.firstMatch(text);
    if (match == null) return null;
    return (
      name: match.group(1)!,
      isError: match.group(2) == 'ERROR',
      seconds: double.tryParse(match.group(3) ?? ''),
      result: match.group(4)!.trim(),
    );
  }
}

/// The `subagent.steer` result.
class ThreadSteerResult {
  const ThreadSteerResult({required this.queued});

  /// `status: queued`. Anything else (`rejected`) means the thread did not
  /// take the text: it finished, or it does not accept steering.
  final bool queued;

  factory ThreadSteerResult.parse(Map<String, dynamic> result) =>
      ThreadSteerResult(queued: result['status'] == 'queued');

  static Map<String, dynamic> params({
    required String sessionId,
    required String subagentId,
    required String text,
  }) => {'session_id': sessionId, 'subagent_id': subagentId, 'text': text};
}

/// The `subagent.interrupt` result.
class ThreadInterruptResult {
  const ThreadInterruptResult({required this.found});

  /// False when the thread had already finished.
  final bool found;

  factory ThreadInterruptResult.parse(Map<String, dynamic> result) =>
      ThreadInterruptResult(found: result['found'] == true);
}

/// The `session.mode.set` result.
class CoordinatorModeResult {
  const CoordinatorModeResult({required this.coordinator, this.pending});

  final bool coordinator;

  /// True when the chat has no stored row yet; the mode is in effect anyway.
  final bool? pending;

  factory CoordinatorModeResult.parse(Map<String, dynamic> result) =>
      CoordinatorModeResult(
        coordinator: result['coordinator'] == true,
        pending: result['pending'] is bool ? result['pending'] as bool : null,
      );

  static Map<String, dynamic> params({
    required String sessionId,
    required bool coordinator,
  }) => {'session_id': sessionId, 'coordinator': coordinator};
}

/// Who answered a thread question.
enum ThreadAnsweredBy {
  user('user'),
  coordinator('coordinator');

  const ThreadAnsweredBy(this.wire);
  final String wire;

  static ThreadAnsweredBy? parse(Object? value) {
    for (final author in values) {
      if (author.wire == value) return author;
    }
    return null;
  }
}

/// `subagent.reply` params, result and the error code of a closed question.
abstract final class ThreadReplyWire {
  /// JSON-RPC error code: the question was already answered, expired or
  /// cancelled. The error message says which.
  static const closedCode = 4090;

  static Map<String, dynamic> params({
    required String sessionId,
    required String subagentId,
    required String questionId,
    required String text,
    ThreadAnsweredBy answeredBy = ThreadAnsweredBy.user,
  }) => {
    'session_id': sessionId,
    'subagent_id': subagentId,
    'question_id': questionId,
    'text': text,
    'answered_by': answeredBy.wire,
  };

  static bool accepted(Map<String, dynamic> result) =>
      result['accepted'] == true;

  /// The prompt sent for "Let coordinator decide". It is an ordinary user
  /// prompt; the coordinator answers with its own tool call.
  static String coordinatorDecidePrompt(String subagentId) =>
      "Answer thread $subagentId's question yourself.";
}

enum ThreadContinueStatus { dispatched, queued, rejected }

/// The `subagent.continue` result.
class ThreadContinueResult {
  const ThreadContinueResult({
    required this.status,
    this.delegationId,
    this.childSessionId,
    this.position,
    this.error,
  });

  final ThreadContinueStatus status;
  final String? delegationId;
  final String? childSessionId;

  /// 1-based place in line, for [ThreadContinueStatus.queued].
  final int? position;

  /// Why the gateway refused, for [ThreadContinueStatus.rejected].
  final String? error;

  factory ThreadContinueResult.parse(Map<String, dynamic> result) =>
      ThreadContinueResult(
        status: switch (result['status']) {
          'dispatched' => ThreadContinueStatus.dispatched,
          'queued' => ThreadContinueStatus.queued,
          _ => ThreadContinueStatus.rejected,
        },
        delegationId: _text(result['delegation_id'], max: 200),
        childSessionId: _text(result['child_session_id'], max: 200),
        position: _int(result['position']),
        error: _text(result['error'], max: 1000),
      );

  static Map<String, dynamic> params({
    required String sessionId,
    required String subagentId,
    required String text,
  }) => {'session_id': sessionId, 'subagent_id': subagentId, 'text': text};
}

/// The payload of a `subagent.*` progress event.
class ThreadProgressEvent {
  const ThreadProgressEvent({
    required this.type,
    required this.subagentId,
    this.goal,
    this.model,
    this.delegationId,
    this.childSessionId,
    this.depth,
    this.taskIndex,
    this.taskCount,
    this.toolCount,
    this.toolName,
    this.toolPreview,
    this.text,
    this.status,
    this.summary,
    this.durationSeconds,
  });

  final String type;
  final String subagentId;
  final String? goal;
  final String? model;
  final String? delegationId;
  final String? childSessionId;
  final int? depth;
  final int? taskIndex;
  final int? taskCount;
  final int? toolCount;
  final String? toolName;
  final String? toolPreview;
  final String? text;

  /// On `subagent.complete`: `completed`, `failed`, `interrupted`, `error`
  /// or `timeout`.
  final String? status;
  final String? summary;
  final double? durationSeconds;

  bool get isComplete => type == ThreadEventType.complete;

  /// `null` for an event that is not thread progress. Older emitters omit
  /// `subagent_id`; those fall back to the task index, as the read-only list
  /// always has.
  static ThreadProgressEvent? parse(String type, Map<String, dynamic> data) {
    const progressTypes = {
      ThreadEventType.spawnRequested,
      ThreadEventType.start,
      ThreadEventType.thinking,
      ThreadEventType.tool,
      ThreadEventType.progress,
      ThreadEventType.complete,
    };
    if (!progressTypes.contains(type)) return null;
    return ThreadProgressEvent(
      type: type,
      subagentId:
          _text(data['subagent_id'], max: 200) ??
          'task-${_int(data['task_index']) ?? 0}',
      goal: _text(data['goal'], max: 500),
      model: _text(data['model'], max: 200),
      delegationId: _text(data['delegation_id'], max: 200),
      childSessionId: _text(data['child_session_id'], max: 200),
      depth: _int(data['depth']),
      taskIndex: _int(data['task_index']),
      taskCount: _int(data['task_count']),
      toolCount: _int(data['tool_count']),
      toolName: _text(data['tool_name'], max: 120),
      toolPreview: _text(data['tool_preview'], max: 500),
      text: _text(data['text'], max: 1000),
      status: _text(data['status'], max: 40)?.toLowerCase(),
      summary: _text(data['summary']),
      durationSeconds: _double(data['duration_seconds']),
    );
  }
}

/// Outcome statuses a thread can end with.
abstract final class ThreadOutcome {
  static const _succeeded = {'completed', 'success'};
  static const _stopped = {'interrupted', 'cancelled', 'canceled'};

  static bool succeeded(String? status) =>
      status == null || _succeeded.contains(status);

  static bool stopped(String? status) => _stopped.contains(status);
}

enum ThreadMessageKind { update, question }

/// The annotation of a thread update or question: `display_metadata` of an
/// `async_delegation_message` parent turn, and the payload of a
/// `subagent.message` event.
class ThreadMessageAnnotation {
  const ThreadMessageAnnotation({
    required this.messageId,
    required this.kind,
    required this.text,
    required this.subagentId,
    this.delegationId,
    this.goal,
    this.sentAt,
    this.mergedCount,
    this.questionId,
    this.options = const [],
    this.timeoutSeconds,
  });

  /// Unique per delivery; cards are de-duplicated on it.
  final String messageId;
  final ThreadMessageKind kind;
  final String text;
  final String subagentId;
  final String? delegationId;
  final String? goal;
  final DateTime? sentAt;

  /// Updates only: how many updates were merged into this one.
  final int? mergedCount;

  /// Questions only.
  final String? questionId;
  final List<String> options;
  final double? timeoutSeconds;

  bool get isQuestion => kind == ThreadMessageKind.question;

  /// When the thread stops waiting for an answer.
  DateTime? get expiresAt {
    final sent = sentAt;
    final timeout = timeoutSeconds;
    if (sent == null || timeout == null) return null;
    return sent.add(Duration(milliseconds: (timeout * 1000).round()));
  }

  static ThreadMessageAnnotation? parse(Object? value) {
    final map = _map(value);
    if (map == null) return null;
    if (map['type'] != null && map['type'] != ThreadDisplayKind.message) {
      return null;
    }
    final subagentId = _text(map['subagent_id'], max: 200);
    final kind = switch (map['kind']) {
      'update' => ThreadMessageKind.update,
      'question' => ThreadMessageKind.question,
      _ => null,
    };
    if (subagentId == null || kind == null) return null;
    final questionId = _text(map['question_id'], max: 200);
    return ThreadMessageAnnotation(
      messageId:
          _text(map['message_id'], max: 200) ??
          '$subagentId:${questionId ?? map['sent_at'] ?? ''}',
      kind: kind,
      text: _text(map['text']) ?? '',
      subagentId: subagentId,
      delegationId: _text(map['delegation_id'], max: 200),
      goal: _text(map['goal'], max: 500),
      sentAt: _epoch(map['sent_at']),
      mergedCount: _int(map['merged_count']),
      questionId: questionId,
      options: _strings(map['options']),
      timeoutSeconds: _double(map['timeout_seconds']),
    );
  }

  static final _updateHeader = RegExp(r'^\[THREAD UPDATE — ([^\],\s]+)\]');
  static final _questionHeader = RegExp(
    r'^\[THREAD QUESTION — ([^\],\s]+), question ([^\]\s]+)\]',
  );

  /// Rebuilds the annotation from the turn's model-facing scaffold text, for
  /// a history row that carries no `display_metadata`. `null` unless [text]
  /// starts with the gateway's own header, so a person's message that merely
  /// mentions a thread is left alone.
  static ThreadMessageAnnotation? fromScaffold(String text, {Object? rowId}) {
    final body = text.trimLeft();
    final question = _questionHeader.firstMatch(body);
    final update = question == null ? _updateHeader.firstMatch(body) : null;
    if (question == null && update == null) return null;
    final subagentId = (question ?? update)!.group(1)!;
    final lines = const LineSplitter().convert(body);
    final marker = question == null ? '--- UPDATE ---' : '--- QUESTION ---';
    final start = lines.indexOf(marker);
    var content = start < 0 ? <String>[] : lines.sublist(start + 1);
    var options = const <String>[];
    if (question != null &&
        content.isNotEmpty &&
        content.last.startsWith('Options: ')) {
      options = content.last
          .substring('Options: '.length)
          .split(' | ')
          .map((option) => option.trim())
          .where((option) => option.isNotEmpty)
          .toList();
      content = content.sublist(0, content.length - 1);
    }
    String? goal;
    for (final line in lines.take(start < 0 ? lines.length : start)) {
      if (line.startsWith('Thread task: ')) {
        goal = _text(line.substring('Thread task: '.length), max: 500);
      }
    }
    final questionId = question?.group(2);
    return ThreadMessageAnnotation(
      messageId: 'row:${rowId ?? questionId ?? body.hashCode}',
      kind: question == null
          ? ThreadMessageKind.update
          : ThreadMessageKind.question,
      text: content.join('\n').trim(),
      subagentId: subagentId,
      goal: goal,
      questionId: questionId,
      options: options,
    );
  }
}

enum ThreadQuestionStatus { pending, answered, expired, cancelled }

/// The payload of a `subagent.question` lifecycle event.
class ThreadQuestionEvent {
  const ThreadQuestionEvent({
    required this.subagentId,
    required this.questionId,
    required this.status,
    this.goal,
    this.question,
    this.answeredBy,
    this.answer,
  });

  final String subagentId;
  final String questionId;
  final ThreadQuestionStatus status;
  final String? goal;

  /// Set for [ThreadQuestionStatus.pending].
  final ThreadQuestionWire? question;

  /// Set for [ThreadQuestionStatus.answered].
  final ThreadAnsweredBy? answeredBy;
  final String? answer;

  static ThreadQuestionEvent? parse(Map<String, dynamic> data) {
    final subagentId = _text(data['subagent_id'], max: 200);
    final questionId = _text(data['question_id'], max: 200);
    final status = switch (data['status']) {
      'pending' => ThreadQuestionStatus.pending,
      'answered' => ThreadQuestionStatus.answered,
      'expired' => ThreadQuestionStatus.expired,
      'cancelled' => ThreadQuestionStatus.cancelled,
      _ => null,
    };
    if (subagentId == null || questionId == null || status == null) {
      return null;
    }
    return ThreadQuestionEvent(
      subagentId: subagentId,
      questionId: questionId,
      status: status,
      goal: _text(data['goal'], max: 500),
      question: status == ThreadQuestionStatus.pending
          ? ThreadQuestionWire.parse(data)
          : null,
      answeredBy: ThreadAnsweredBy.parse(data['answered_by']),
      answer: _text(data['answer']),
    );
  }
}

/// One thread of a completion report.
class ThreadReportEntry {
  const ThreadReportEntry({
    this.subagentId,
    this.taskIndex,
    this.goal,
    this.status,
    this.toolCount,
    this.durationSeconds,
    this.summary,
  });

  /// Absent on a legacy completion; needed for Open thread and Continue.
  final String? subagentId;
  final int? taskIndex;
  final String? goal;

  /// `completed`, `failed`, `interrupted`, `error` or `timeout`.
  final String? status;
  final int? toolCount;
  final double? durationSeconds;

  /// The thread's result text, read from the turn's content: the annotation
  /// carries none.
  final String? summary;

  ThreadReportEntry withFallback(ThreadReportEntry other) => ThreadReportEntry(
    subagentId: subagentId ?? other.subagentId,
    taskIndex: taskIndex ?? other.taskIndex,
    goal: goal ?? other.goal,
    status: status ?? other.status,
    toolCount: toolCount ?? other.toolCount,
    durationSeconds: durationSeconds ?? other.durationSeconds,
    summary: summary ?? other.summary,
  );
}

/// A finished thread's report: an `async_delegation_complete` parent turn.
class ThreadReportAnnotation {
  const ThreadReportAnnotation({
    this.delegationId,
    this.entries = const [],
    this.earlyFailure = false,
  });

  final String? delegationId;

  /// One entry per thread that reported in this turn.
  final List<ThreadReportEntry> entries;

  /// An early warning for one failed task of a batch that is still running.
  final bool earlyFailure;

  static final _header = RegExp(
    r'^\[ASYNC DELEGATION (COMPLETE|BATCH COMPLETE|TASK FAILED) — ([^\],\s]+)'
    r'(?:, task (\d+)/\d+)?\]',
  );
  static final _status = RegExp(r'^Status: (\S+)');
  static final _duration = RegExp(r'Duration: (\d+(?:\.\d+)?)s');
  static final _batchTask = RegExp(
    r'^--- \S+ TASK (\d+)/\d+(?:: (.*?))?  \(status=([^,)]+)'
    r'(?:, api_calls=\d+)?(?:, (\d+(?:\.\d+)?)s)?.*\) ---$',
  );
  static const _dropPrefixes = [
    'Full live transcript',
    'Live transcript:',
    'Handed off to you:',
    'Child left ',
    "Child's process ",
  ];

  /// Classifies one stored user row.
  ///
  /// The server annotation is authoritative: [displayKind] and
  /// [displayMetadata] when the gateway sent them. A row without them is
  /// classified by the gateway's own header at the very start of [content]
  /// (a legacy turn); a person's message that quotes that header further
  /// down is left alone. The result text always comes from [content].
  static ThreadReportAnnotation? classify({
    required String content,
    Object? displayKind,
    Object? displayMetadata,
  }) {
    if (displayKind is String &&
        displayKind.isNotEmpty &&
        displayKind != ThreadDisplayKind.complete) {
      return null;
    }
    final body = content.trimLeft();
    final header = _header.firstMatch(body);
    final metadata = _map(displayMetadata);
    final annotated =
        displayKind == ThreadDisplayKind.complete && metadata != null;
    if (header == null && !annotated) return null;

    final fromText = header == null
        ? const <ThreadReportEntry>[]
        : _entriesFromText(body, header);
    final fromMetadata = [
      for (final row in _maps(metadata?['threads']))
        ThreadReportEntry(
          subagentId: _text(row['subagent_id'], max: 200),
          taskIndex: _int(row['task_index']),
          goal: _text(row['goal'], max: 500),
          status: _text(row['status'], max: 40)?.toLowerCase(),
          toolCount: _int(row['tool_count']),
          durationSeconds: _double(row['duration_seconds']),
        ),
    ];

    final List<ThreadReportEntry> entries;
    if (fromMetadata.isEmpty) {
      entries = fromText;
    } else {
      entries = [
        for (final (position, entry) in fromMetadata.indexed)
          entry.withFallback(
            fromText.firstWhere(
              (candidate) =>
                  candidate.taskIndex != null &&
                  candidate.taskIndex == entry.taskIndex,
              orElse: () => fromText.length == fromMetadata.length
                  ? fromText[position]
                  : const ThreadReportEntry(),
            ),
          ),
      ];
    }
    if (entries.isEmpty) {
      // An annotated completion with no per-thread rows and no parseable
      // text (a crashed unit): still a report, with only its title.
      final title = _text(metadata?['display_text'], max: 500);
      return ThreadReportAnnotation(
        delegationId:
            _text(metadata?['delegation_id'], max: 200) ?? header?.group(2),
        entries: [
          ThreadReportEntry(
            goal: title,
            status: (_int(metadata?['failed_count']) ?? 0) > 0
                ? 'failed'
                : null,
            durationSeconds: _double(metadata?['duration_seconds']),
          ),
        ],
      );
    }
    return ThreadReportAnnotation(
      delegationId:
          _text(metadata?['delegation_id'], max: 200) ?? header?.group(2),
      entries: entries,
      earlyFailure: header?.group(1) == 'TASK FAILED',
    );
  }

  static String? _clean(List<String> lines) {
    final kept = lines.where(
      (line) => !_dropPrefixes.any((prefix) => line.startsWith(prefix)),
    );
    return _text(kept.join('\n'));
  }

  static List<ThreadReportEntry> _entriesFromText(
    String body,
    RegExpMatch header,
  ) {
    final lines = const LineSplitter().convert(body);
    final kind = header.group(1)!;

    if (kind == 'BATCH COMPLETE') {
      final entries = <ThreadReportEntry>[];
      int? index;
      String? goal;
      String? status;
      double? seconds;
      var summary = <String>[];
      void flush() {
        if (index == null) return;
        entries.add(
          ThreadReportEntry(
            taskIndex: index,
            goal: goal,
            status: status,
            durationSeconds: seconds,
            summary: _clean(summary),
          ),
        );
      }

      for (final line in lines.skip(1)) {
        final task = _batchTask.firstMatch(line);
        if (task != null) {
          flush();
          index = int.parse(task.group(1)!) - 1;
          goal = _text(task.group(2), max: 500);
          status = task.group(3)?.toLowerCase();
          seconds = double.tryParse(task.group(4) ?? '');
          summary = [];
        } else if (index != null) {
          summary.add(line);
        }
      }
      flush();
      return entries;
    }

    String? goal;
    String? status;
    double? seconds;
    String? error;
    var resultStart = -1;
    for (final (position, line) in lines.indexed) {
      if (line == '--- RESULT ---') {
        resultStart = position + 1;
        break;
      }
      if (line.startsWith('Original goal: ')) {
        goal = _text(line.substring('Original goal: '.length), max: 500);
      } else if (line.startsWith('Task: ')) {
        goal = _text(line.substring('Task: '.length), max: 500);
      } else if (line.startsWith('Error: ')) {
        error = _text(line.substring('Error: '.length), max: 1000);
      }
      final statusMatch = _status.firstMatch(line);
      if (statusMatch != null) {
        status = statusMatch.group(1)!.toLowerCase();
        seconds = double.tryParse(_duration.firstMatch(line)?.group(1) ?? '');
      }
    }
    return [
      ThreadReportEntry(
        taskIndex: kind == 'TASK FAILED'
            ? (int.tryParse(header.group(3) ?? '') ?? 1) - 1
            : null,
        goal: goal,
        status: status ?? (kind == 'TASK FAILED' ? 'failed' : null),
        durationSeconds: seconds,
        summary: resultStart < 0 ? error : _clean(lines.sublist(resultStart)),
      ),
    ];
  }
}

/// The thread that raised an approval: `subagent_id` and `goal` on an
/// `approval` server request. `null` for the main agent's own approvals.
class ThreadApprovalAttribution {
  const ThreadApprovalAttribution({required this.subagentId, this.goal});

  final String subagentId;
  final String? goal;

  static ThreadApprovalAttribution? parse(Map<String, dynamic> params) {
    final subagentId = _text(params['subagent_id'], max: 200);
    if (subagentId == null) return null;
    return ThreadApprovalAttribution(
      subagentId: subagentId,
      goal: _text(params['goal'], max: 200),
    );
  }
}
