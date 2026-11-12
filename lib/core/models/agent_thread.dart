/// A thread: one background subagent of a chat.
library;

/// What a thread is doing, as the roster shows it.
enum AgentThreadState {
  /// A follow-up waiting for a free background slot.
  queued,
  running,

  /// Waiting for an answer to a question it asked.
  needsYou,
  done,
  failed,

  /// Interrupted by the user.
  stopped;

  /// Still holds, or waits for, a background slot.
  bool get isActive =>
      this == AgentThreadState.queued ||
      this == AgentThreadState.running ||
      this == AgentThreadState.needsYou;

  /// Has a live agent that can be tailed, steered and stopped.
  bool get isLive =>
      this == AgentThreadState.running || this == AgentThreadState.needsYou;

  bool get isFinished => !isActive;
}

/// A question a thread is waiting on.
class AgentThreadQuestion {
  const AgentThreadQuestion({
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
}

class AgentThread {
  const AgentThread({
    required this.id,
    required this.goal,
    required this.state,
    this.delegationId,
    this.model,
    this.toolCount = 0,
    this.spawnedAt,
    this.startedAt,
    this.endedAt,
    this.durationSeconds,
    this.lastTool,
    this.acceptingSteer,
    this.childSessionId,
    this.pendingQuestion,
    this.summary,
    this.outcome,
  });

  /// The gateway's `subagent_id`. It stays the same when a finished thread
  /// is continued.
  final String id;

  /// The task the coordinator gave the thread. Empty until known.
  final String goal;
  final AgentThreadState state;
  final String? delegationId;
  final String? model;
  final int toolCount;

  /// When the thread was first started. Unlike [startedAt] it does not move
  /// when the thread is continued, so it names the parent turn that started
  /// the thread. `null` for a thread only known from a failure record.
  final DateTime? spawnedAt;

  /// When the current run started: the gateway's time when it reports one,
  /// else the moment this device first saw the run.
  final DateTime? startedAt;
  final DateTime? endedAt;

  /// The gateway's own measure of a finished run.
  final double? durationSeconds;
  final String? lastTool;

  /// `false` when the gateway says this thread does not take steer text.
  /// `null` when it has not said.
  final bool? acceptingSteer;

  /// The stored session holding the thread's transcript.
  final String? childSessionId;
  final AgentThreadQuestion? pendingQuestion;

  /// The result text of a finished thread, when an event carried it.
  final String? summary;

  /// The gateway's raw end status (`completed`, `failed`, `timeout`, ...).
  final String? outcome;

  /// How long the thread has run, or ran.
  Duration? elapsed(DateTime now) {
    final seconds = durationSeconds;
    if (state.isFinished && seconds != null) {
      return Duration(milliseconds: (seconds * 1000).round());
    }
    final start = startedAt;
    if (start == null) return null;
    final end = state.isFinished ? (endedAt ?? now) : now;
    return end.isBefore(start) ? Duration.zero : end.difference(start);
  }

  static const _unset = Object();

  AgentThread copyWith({
    String? goal,
    AgentThreadState? state,
    String? delegationId,
    String? model,
    int? toolCount,
    DateTime? spawnedAt,
    DateTime? startedAt,
    Object? endedAt = _unset,
    Object? durationSeconds = _unset,
    String? lastTool,
    bool? acceptingSteer,
    String? childSessionId,
    Object? pendingQuestion = _unset,
    Object? summary = _unset,
    Object? outcome = _unset,
  }) => AgentThread(
    id: id,
    goal: goal ?? this.goal,
    state: state ?? this.state,
    delegationId: delegationId ?? this.delegationId,
    model: model ?? this.model,
    toolCount: toolCount ?? this.toolCount,
    spawnedAt: spawnedAt ?? this.spawnedAt,
    startedAt: startedAt ?? this.startedAt,
    endedAt: identical(endedAt, _unset) ? this.endedAt : endedAt as DateTime?,
    durationSeconds: identical(durationSeconds, _unset)
        ? this.durationSeconds
        : durationSeconds as double?,
    lastTool: lastTool ?? this.lastTool,
    acceptingSteer: acceptingSteer ?? this.acceptingSteer,
    childSessionId: childSessionId ?? this.childSessionId,
    pendingQuestion: identical(pendingQuestion, _unset)
        ? this.pendingQuestion
        : pendingQuestion as AgentThreadQuestion?,
    summary: identical(summary, _unset) ? this.summary : summary as String?,
    outcome: identical(outcome, _unset) ? this.outcome : outcome as String?,
  );
}
