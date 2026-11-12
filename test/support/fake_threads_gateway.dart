// ignore_for_file: prefer_initializing_formals

import 'package:flutter/foundation.dart';
import 'package:hermes_android/core/services/agent_threads_controller.dart';
import 'package:hermes_android/core/services/thread_wire.dart';

/// An in-memory [AgentThreadsGateway] that records every call.
class FakeThreadsGateway extends ChangeNotifier implements AgentThreadsGateway {
  FakeThreadsGateway({ThreadSupport support = ThreadSupport.stock})
    : _support = support;

  ThreadSupport _support;

  /// What [probe] turns [support] into, when set: a stock gateway that
  /// proves itself only once probed.
  ThreadSupport? supportAfterProbe;

  /// Method names in call order, with their arguments.
  final List<String> calls = [];

  ThreadRosterSnapshot roster = const ThreadRosterSnapshot();
  DelegationStatusSnapshot status = const DelegationStatusSnapshot(
    activeCount: 0,
    paused: false,
    maxConcurrent: 3,
  );
  ThreadTailSnapshot tailSnapshot = const ThreadTailSnapshot(available: false);
  ThreadSteerResult steerResult = const ThreadSteerResult(queued: true);
  bool interruptFound = true;
  ThreadContinueResult continueResult = const ThreadContinueResult(
    status: ThreadContinueStatus.dispatched,
  );

  /// Thrown by the next call to the named method, once.
  final Map<String, Object> failures = {};

  int callCount(String name) =>
      calls.where((call) => call == name || call.startsWith('$name ')).length;

  @override
  ThreadSupport get support => _support;

  set support(ThreadSupport value) {
    _support = value;
    notifyListeners();
  }

  @override
  Listenable get supportChanges => this;

  void _record(String name, [String? detail]) {
    calls.add(detail == null ? name : '$name $detail');
    final failure = failures.remove(name);
    if (failure != null) throw failure;
  }

  @override
  Future<void> probe() async {
    _record('probe');
    final next = supportAfterProbe;
    if (next != null) _support = next;
  }

  @override
  Future<ThreadRosterSnapshot> listThreads() async {
    _record('list');
    return roster;
  }

  @override
  Future<DelegationStatusSnapshot> delegationStatus() async {
    _record('status');
    return status;
  }

  @override
  Future<bool> setPaused(bool paused) async {
    _record('pause', '$paused');
    status = DelegationStatusSnapshot(
      activeCount: status.activeCount,
      paused: paused,
      maxConcurrent: status.maxConcurrent,
      model: status.model,
    );
    return paused;
  }

  @override
  Future<ThreadTailSnapshot> tail(String subagentId) async {
    _record('tail', subagentId);
    return tailSnapshot;
  }

  @override
  Future<ThreadSteerResult> steer(String subagentId, String text) async {
    _record('steer', '$subagentId|$text');
    return steerResult;
  }

  @override
  Future<ThreadInterruptResult> interrupt(String subagentId) async {
    _record('interrupt', subagentId);
    return ThreadInterruptResult(found: interruptFound);
  }

  @override
  Future<void> reply({
    required String subagentId,
    required String questionId,
    required String text,
  }) async {
    _record('reply', '$subagentId|$questionId|$text');
  }

  @override
  Future<ThreadContinueResult> continueThread(
    String subagentId,
    String text,
  ) async {
    _record('continue', '$subagentId|$text');
    return continueResult;
  }

  @override
  Future<void> ensureSession() async {
    _record('ensureSession');
  }

  @override
  Future<CoordinatorModeResult> setCoordinatorMode(bool coordinator) async {
    _record('mode', '$coordinator');
    return CoordinatorModeResult(coordinator: coordinator);
  }
}

ThreadRosterRow rosterRow(
  String id, {
  String goal = 'Thread',
  int tools = 0,
  String? model,
  double? startedAt,
  bool? acceptingSteer,
  String? childSessionId,
  String? delegationId,
  Map<String, dynamic>? question,
}) => ThreadRosterRow.parse({
  'subagent_id': id,
  'goal': goal,
  'tool_count': tools,
  'model': model,
  'started_at': startedAt,
  'status': 'running',
  'accepting_steer': acceptingSteer,
  'child_session_id': childSessionId,
  'delegation_id': delegationId,
  'pending_question': question,
})!;
