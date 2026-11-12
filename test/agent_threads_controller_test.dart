import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/agent_thread.dart';
import 'package:hermes_android/core/services/agent_threads_controller.dart';
import 'package:hermes_android/core/services/thread_wire.dart';
import 'package:hermes_android/core/services/ws_client.dart';

import 'support/fake_threads_gateway.dart';

final _now = DateTime.utc(2026, 11, 11, 14, 30);

AgentThreadsController _controller(FakeThreadsGateway gateway) {
  final controller = AgentThreadsController(
    gateway: gateway,
    clock: () => _now,
  );
  addTearDown(controller.dispose);
  return controller;
}

Map<String, dynamic> _event(
  String id, {
  String goal = 'Audit',
  Object? extra,
}) => {
  'subagent_id': id,
  'goal': goal,
  'task_index': 0,
  'task_count': 1,
  if (extra is Map<String, dynamic>) ...extra,
};

void main() {
  group('seed', () {
    test('reads the roster, slot usage and pause from the gateway', () async {
      final gateway = FakeThreadsGateway()
        ..roster = ThreadRosterSnapshot(
          threads: [
            rosterRow(
              'a',
              goal: 'Audit licences',
              tools: 7,
              model: 'sonnet',
              startedAt: 1767000000,
              childSessionId: 'child-a',
            ),
            rosterRow(
              'b',
              goal: 'Check CI',
              question: {'question_id': 'q1', 'text': 'Re-run?'},
            ),
          ],
        )
        ..status = const DelegationStatusSnapshot(
          activeCount: 2,
          paused: true,
          maxConcurrent: 3,
          model: 'sonnet',
        );
      final controller = _controller(gateway);

      await controller.seed();

      expect(controller.threads.map((t) => t.id), ['b', 'a']);
      final a = controller.thread('a')!;
      expect(a.state, AgentThreadState.running);
      expect(a.goal, 'Audit licences');
      expect(a.toolCount, 7);
      expect(a.model, 'sonnet');
      expect(a.childSessionId, 'child-a');
      expect(controller.thread('b')!.state, AgentThreadState.needsYou);
      expect(controller.thread('b')!.pendingQuestion?.questionId, 'q1');
      expect(controller.slotsInUse, 2);
      expect(controller.slotLimit, 3);
      expect(controller.paused, isTrue);
    });

    test('a stock gateway is probed, then seeded', () async {
      final gateway = FakeThreadsGateway(support: ThreadSupport.none)
        ..supportAfterProbe = ThreadSupport.stock
        ..roster = ThreadRosterSnapshot(threads: [rosterRow('a')]);
      final controller = _controller(gateway);
      expect(controller.support.roster, isFalse);

      await controller.seed();

      expect(gateway.calls.take(2), ['probe', 'list']);
      expect(controller.support.roster, isTrue);
      expect(controller.thread('a'), isNotNull);
    });

    test('without thread support nothing is listed', () async {
      final gateway = FakeThreadsGateway(support: ThreadSupport.none);
      final controller = _controller(gateway);

      await controller.seed();

      expect(gateway.calls, ['probe']);
      expect(controller.hasThreads, isFalse);
      expect(controller.support.roster, isFalse);
    });

    test('nested children are not the chat\'s threads', () async {
      final gateway = FakeThreadsGateway()
        ..roster = ThreadRosterSnapshot(
          threads: [
            rosterRow('a'),
            ThreadRosterRow.parse({
              'subagent_id': 'a-child',
              'parent_id': 'a',
              'depth': 1,
            })!,
          ],
        );
      final controller = _controller(gateway);

      await controller.seed();

      expect(controller.threads.map((t) => t.id), ['a']);
    });

    test('support that arrives later triggers a seed', () async {
      final gateway = FakeThreadsGateway(support: ThreadSupport.none);
      final controller = _controller(gateway);
      await controller.seed();
      gateway.roster = ThreadRosterSnapshot(threads: [rosterRow('a')]);

      // A session.info event advertised the keys.
      gateway.support = ThreadSupport.full;
      await pumpEventQueue();

      expect(controller.support.messages, isTrue);
      expect(controller.thread('a'), isNotNull);
    });
  });

  group('events', () {
    test('build a thread from spawn to completion', () {
      final controller = _controller(FakeThreadsGateway());
      final finished = <AgentThread>[];
      controller.onThreadFinished = finished.add;

      controller.applyEvent(ThreadEventType.spawnRequested, _event('a'));
      expect(controller.thread('a')!.state, AgentThreadState.running);
      expect(controller.thread('a')!.spawnedAt, _now);

      controller.applyEvent(
        ThreadEventType.start,
        _event('a', extra: {'model': 'sonnet', 'child_session_id': 'child-a'}),
      );
      controller.applyEvent(
        ThreadEventType.tool,
        _event('a', extra: {'tool_name': 'terminal'}),
      );
      controller.applyEvent(
        ThreadEventType.tool,
        _event('a', extra: {'tool_name': 'read_file'}),
      );
      final running = controller.thread('a')!;
      expect(running.toolCount, 2);
      expect(running.lastTool, 'read_file');
      expect(running.model, 'sonnet');
      expect(running.childSessionId, 'child-a');

      controller.applyEvent(
        ThreadEventType.complete,
        _event(
          'a',
          extra: {
            'status': 'completed',
            'summary': 'All MIT.',
            'tool_count': 12,
            'duration_seconds': 184.2,
          },
        ),
      );
      final done = controller.thread('a')!;
      expect(done.state, AgentThreadState.done);
      expect(done.summary, 'All MIT.');
      expect(done.toolCount, 12);
      expect(done.elapsed(_now), const Duration(milliseconds: 184200));
      expect(finished.single.id, 'a');
    });

    test('completion status decides done, failed or stopped', () {
      final controller = _controller(FakeThreadsGateway());
      for (final (id, status, state) in [
        ('ok', 'completed', AgentThreadState.done),
        ('err', 'error', AgentThreadState.failed),
        ('late', 'timeout', AgentThreadState.failed),
        ('cut', 'interrupted', AgentThreadState.stopped),
      ]) {
        controller.applyEvent(ThreadEventType.start, _event(id));
        controller.applyEvent(
          ThreadEventType.complete,
          _event(id, extra: {'status': status}),
        );
        expect(controller.thread(id)!.state, state, reason: status);
      }
    });

    test('keep the read-only list an old gateway shows', () {
      final controller = _controller(
        FakeThreadsGateway(support: ThreadSupport.none),
      );

      controller.applyEvent(ThreadEventType.start, _event('a', goal: 'Audit'));
      controller.applyEvent(
        ThreadEventType.complete,
        _event('a', goal: 'Audit'),
      );

      expect(controller.legacyActivities.single.goal, 'Audit');
      expect(controller.legacyActivities.single.isComplete, isTrue);
    });

    test('a late progress event does not revive a finished thread', () {
      final controller = _controller(FakeThreadsGateway());
      controller.applyEvent(ThreadEventType.start, _event('a'));
      controller.applyEvent(
        ThreadEventType.complete,
        _event('a', extra: {'status': 'completed'}),
      );

      controller.applyEvent(ThreadEventType.thinking, _event('a'));

      expect(controller.thread('a')!.state, AgentThreadState.done);
    });

    test('a start after completion is the same thread running again', () {
      final controller = _controller(FakeThreadsGateway());
      controller.applyEvent(ThreadEventType.start, _event('a'));
      controller.applyEvent(
        ThreadEventType.complete,
        _event('a', extra: {'status': 'completed', 'summary': 'First.'}),
      );

      controller.applyEvent(ThreadEventType.spawnRequested, _event('a'));

      final again = controller.thread('a')!;
      expect(again.state, AgentThreadState.running);
      expect(again.summary, isNull);
      expect(again.toolCount, 0);
      expect(controller.threads, hasLength(1));
    });

    test('other event types are not thread events', () {
      final controller = _controller(FakeThreadsGateway());
      expect(controller.applyEvent('tool.start', {'name': 'x'}), isFalse);
      expect(controller.hasThreads, isFalse);
    });
  });

  group('re-seed', () {
    test('repairs a completion missed while disconnected', () async {
      final gateway = FakeThreadsGateway()
        ..roster = ThreadRosterSnapshot(
          threads: [rosterRow('a'), rosterRow('b')],
        );
      final controller = _controller(gateway);
      await controller.seed();
      expect(controller.activeThreads, hasLength(2));

      // The socket drops; "a" finishes; no subagent.complete ever arrives.
      gateway.roster = ThreadRosterSnapshot(
        threads: [rosterRow('b', tools: 4)],
      );
      await controller.seed();

      expect(controller.thread('a')!.state, AgentThreadState.done);
      expect(controller.thread('a')!.endedAt, _now);
      expect(controller.thread('b')!.state, AgentThreadState.running);
      expect(controller.thread('b')!.toolCount, 4);
    });

    test('a missed failure is read from the failed delegations', () async {
      final gateway = FakeThreadsGateway()
        ..roster = ThreadRosterSnapshot(
          threads: [rosterRow('a', delegationId: 'deleg_1')],
        );
      final controller = _controller(gateway);
      await controller.seed();

      gateway.roster = ThreadRosterSnapshot(
        failed: [
          ThreadFailedDelegation.parse({
            'delegation_id': 'deleg_1',
            'status': 'error',
            'goal': 'Thread',
            'error': 'model not found',
          })!,
        ],
      );
      await controller.seed();

      final thread = controller.thread('a')!;
      expect(thread.state, AgentThreadState.failed);
      expect(thread.summary, 'model not found');
      // The failure record is the same thread, not a second entry.
      expect(controller.threads, hasLength(1));
    });

    test('a failed seed keeps what the events built', () async {
      final gateway = FakeThreadsGateway();
      final controller = _controller(gateway);
      controller.applyEvent(ThreadEventType.start, _event('a'));
      gateway.failures['list'] = JsonRpcError('subagent.list', 'Timeout');

      await controller.seed();

      expect(controller.thread('a')!.state, AgentThreadState.running);
    });

    test('closes a question the roster no longer lists', () async {
      final gateway = FakeThreadsGateway()
        ..roster = ThreadRosterSnapshot(threads: [rosterRow('a')]);
      final controller = _controller(gateway);
      await controller.seed();
      controller.applyEvent(ThreadEventType.question, {
        'subagent_id': 'a',
        'question_id': 'q1',
        'status': 'pending',
        'text': 'Drop them?',
      });
      expect(controller.thread('a')!.state, AgentThreadState.needsYou);
      expect(
        controller.questionRecord('a', 'q1').state,
        ThreadQuestionState.pending,
      );

      // Reconnect: the answered/expired event was missed.
      await controller.seed();

      expect(controller.thread('a')!.state, AgentThreadState.running);
      expect(
        controller.questionRecord('a', 'q1').state,
        ThreadQuestionState.closed,
      );
    });

    test('queued follow-ups are listed as queued', () async {
      final gateway = FakeThreadsGateway()
        ..roster = ThreadRosterSnapshot(
          queued: [
            ThreadQueuedRow.parse({'subagent_id': 'a', 'goal': 'Notes'})!,
          ],
        );
      final controller = _controller(gateway);

      await controller.seed();

      expect(controller.thread('a')!.state, AgentThreadState.queued);
      expect(controller.queuePosition('a'), 1);
    });
  });

  group('order', () {
    test(
      'needs-you first, then running, queued, and finished newest first',
      () async {
        var now = _now;
        final gateway = FakeThreadsGateway();
        final controller = AgentThreadsController(
          gateway: gateway,
          clock: () => now,
        );
        addTearDown(controller.dispose);
        for (final id in ['run1', 'done-old', 'wait', 'run2', 'done-new']) {
          controller.applyEvent(ThreadEventType.start, _event(id));
        }
        controller.applyEvent(
          ThreadEventType.complete,
          _event('done-old', extra: {'status': 'completed'}),
        );
        now = now.add(const Duration(minutes: 1));
        controller.applyEvent(
          ThreadEventType.complete,
          _event('done-new', extra: {'status': 'completed'}),
        );
        controller.applyEvent(ThreadEventType.question, {
          'subagent_id': 'wait',
          'question_id': 'q1',
          'status': 'pending',
          'text': '?',
        });
        gateway.continueResult = const ThreadContinueResult(
          status: ThreadContinueStatus.queued,
          position: 1,
        );
        controller.rememberFinished(id: 'queued', goal: 'Queued');
        await controller.continueThread('queued', 'again');

        expect(controller.threads.map((t) => t.id), [
          'wait',
          'run1',
          'run2',
          'queued',
          'done-new',
          'done-old',
        ]);
        expect(controller.activeThreads.map((t) => t.id), [
          'wait',
          'run1',
          'run2',
          'queued',
        ]);
        expect(controller.finishedThreads.map((t) => t.id), [
          'done-new',
          'done-old',
        ]);
      },
    );
  });

  group('actions', () {
    test('stop marks the thread once the gateway confirms', () async {
      final gateway = FakeThreadsGateway();
      final controller = _controller(gateway);
      controller.applyEvent(ThreadEventType.start, _event('a'));

      expect(await controller.stop('a'), isTrue);

      expect(gateway.calls, contains('interrupt a'));
      expect(controller.thread('a')!.state, AgentThreadState.stopped);

      // The interrupted run's own completion keeps it stopped.
      controller.applyEvent(
        ThreadEventType.complete,
        _event('a', extra: {'status': 'failed'}),
      );
      expect(controller.thread('a')!.state, AgentThreadState.stopped);
    });

    test('stop of an already finished thread re-reads the roster', () async {
      final gateway = FakeThreadsGateway()..interruptFound = false;
      final controller = _controller(gateway);
      controller.applyEvent(ThreadEventType.start, _event('a'));

      expect(await controller.stop('a'), isFalse);
      await pumpEventQueue();

      expect(gateway.calls, contains('list'));
      expect(controller.thread('a')!.state, AgentThreadState.done);
    });

    test('stop all interrupts every running thread of this chat', () async {
      final gateway = FakeThreadsGateway();
      final controller = _controller(gateway);
      for (final id in ['a', 'b', 'c']) {
        controller.applyEvent(ThreadEventType.start, _event(id));
      }
      controller.applyEvent(
        ThreadEventType.complete,
        _event('c', extra: {'status': 'completed'}),
      );

      expect(await controller.stopAll(), 2);

      expect(gateway.calls.where((c) => c.startsWith('interrupt')), [
        'interrupt a',
        'interrupt b',
      ]);
      expect(controller.activeThreads, isEmpty);
    });

    test('pause is sent to the gateway and reflected', () async {
      final gateway = FakeThreadsGateway();
      final controller = _controller(gateway);

      await controller.setPaused(true);

      expect(gateway.calls, ['pause true']);
      expect(controller.paused, isTrue);
    });

    test('a steer is acknowledged by the thread\'s next step', () async {
      final gateway = FakeThreadsGateway();
      final controller = _controller(gateway);
      controller.applyEvent(ThreadEventType.start, _event('a'));

      final record = await controller.steer('a', ' Skip dev-only deps ');

      expect(gateway.calls, ['steer a|Skip dev-only deps']);
      expect(record.status, ThreadSteerStatus.sent);

      controller.applyEvent(
        ThreadEventType.tool,
        _event('a', extra: {'tool_name': 'terminal'}),
      );
      expect(
        controller.steerRecord('a')!.status,
        ThreadSteerStatus.acknowledged,
      );
    });

    test('a steer that races with completion did not land', () async {
      final gateway = FakeThreadsGateway();
      final controller = _controller(gateway);
      controller.applyEvent(ThreadEventType.start, _event('a'));
      await controller.steer('a', 'Skip dev-only deps');

      controller.applyEvent(
        ThreadEventType.complete,
        _event('a', extra: {'status': 'completed'}),
      );

      final record = controller.steerRecord('a')!;
      expect(record.status, ThreadSteerStatus.didNotLand);
      expect(record.text, 'Skip dev-only deps');
    });

    test('a rejected steer did not land', () async {
      final gateway = FakeThreadsGateway()
        ..steerResult = const ThreadSteerResult(queued: false);
      final controller = _controller(gateway);
      controller.applyEvent(ThreadEventType.start, _event('a'));

      final record = await controller.steer('a', 'too late');

      expect(record.status, ThreadSteerStatus.didNotLand);
    });
  });

  group('questions', () {
    AgentThreadsController asked(FakeThreadsGateway gateway) {
      final controller = _controller(gateway);
      controller.applyEvent(ThreadEventType.start, _event('a', goal: 'Audit'));
      controller.applyEvent(ThreadEventType.question, {
        'subagent_id': 'a',
        'question_id': 'q1',
        'status': 'pending',
        'goal': 'Audit',
        'text': 'Drop the two AGPL packages?',
        'options': ['Drop', 'Flag for legal'],
      });
      return controller;
    }

    test('a pending question puts the thread in needs-you', () {
      final gateway = FakeThreadsGateway(support: ThreadSupport.full);
      final questions = <String>[];
      final controller = _controller(gateway)
        ..onThreadQuestion = (thread, question) => questions.add(question.text);
      controller.applyEvent(ThreadEventType.start, _event('a'));

      controller.applyEvent(ThreadEventType.question, {
        'subagent_id': 'a',
        'question_id': 'q1',
        'status': 'pending',
        'text': 'Drop them?',
      });

      expect(controller.thread('a')!.state, AgentThreadState.needsYou);
      expect(controller.threads.first.id, 'a');
      expect(questions, ['Drop them?']);
    });

    test('a reply goes to that thread and records the answer', () async {
      final gateway = FakeThreadsGateway(support: ThreadSupport.full);
      final controller = asked(gateway);

      await controller.reply(
        subagentId: 'a',
        questionId: 'q1',
        text: 'Flag them for legal',
      );

      expect(gateway.calls, ['reply a|q1|Flag them for legal']);
      final record = controller.questionRecord('a', 'q1');
      expect(record.state, ThreadQuestionState.answered);
      expect(record.answer, 'Flag them for legal');
      expect(record.answeredBy, ThreadAnsweredBy.user);
      expect(controller.thread('a')!.state, AgentThreadState.running);
    });

    test('a duplicate reply is rejected and the question closed', () async {
      final gateway = FakeThreadsGateway(support: ThreadSupport.full);
      final controller = asked(gateway);
      gateway.failures['reply'] = JsonRpcError(
        ThreadRpc.reply,
        'Question q1 is closed: it was already answered by the coordinator.',
        code: ThreadReplyWire.closedCode,
      );

      await expectLater(
        controller.reply(subagentId: 'a', questionId: 'q1', text: 'late'),
        throwsA(
          isA<ThreadQuestionClosedException>().having(
            (e) => e.message,
            'message',
            contains('already answered by the coordinator'),
          ),
        ),
      );

      expect(
        controller.questionRecord('a', 'q1').state,
        ThreadQuestionState.closed,
      );
      expect(controller.thread('a')!.state, AgentThreadState.running);
    });

    test('the coordinator\'s answer arrives as an event', () {
      final controller = asked(FakeThreadsGateway(support: ThreadSupport.full));
      controller.markCoordinatorDeciding(subagentId: 'a', questionId: 'q1');
      expect(
        controller.questionRecord('a', 'q1').state,
        ThreadQuestionState.deciding,
      );
      // Still waiting: the thread stays in needs-you until answered.
      expect(controller.thread('a')!.state, AgentThreadState.needsYou);

      controller.applyEvent(ThreadEventType.question, {
        'subagent_id': 'a',
        'question_id': 'q1',
        'status': 'answered',
        'answered_by': 'coordinator',
        'answer': 'Flag them.',
      });

      final record = controller.questionRecord('a', 'q1');
      expect(record.state, ThreadQuestionState.answered);
      expect(record.answeredBy, ThreadAnsweredBy.coordinator);
      expect(record.answer, 'Flag them.');
      expect(controller.thread('a')!.state, AgentThreadState.running);
    });

    test('an expired question leaves needs-you', () {
      final controller = asked(FakeThreadsGateway(support: ThreadSupport.full));

      controller.applyEvent(ThreadEventType.question, {
        'subagent_id': 'a',
        'question_id': 'q1',
        'status': 'expired',
      });

      expect(
        controller.questionRecord('a', 'q1').state,
        ThreadQuestionState.expired,
      );
      expect(controller.thread('a')!.state, AgentThreadState.running);
    });

    test('an unknown question is open only while the roster says so', () async {
      final gateway = FakeThreadsGateway(support: ThreadSupport.full)
        ..roster = ThreadRosterSnapshot(
          threads: [
            rosterRow('a', question: {'question_id': 'q7', 'text': '?'}),
          ],
        );
      final controller = _controller(gateway);
      await controller.seed();

      expect(
        controller.questionRecord('a', 'q7').state,
        ThreadQuestionState.pending,
      );
      expect(
        controller.questionRecord('a', 'q-old').state,
        ThreadQuestionState.closed,
      );
    });

    test('live messages are kept once per message id', () {
      final controller = _controller(
        FakeThreadsGateway(support: ThreadSupport.full),
      );
      final payload = {
        'type': 'async_delegation_message',
        'message_id': 'dmsg_1',
        'kind': 'update',
        'text': '2 of 5 jobs fail',
        'subagent_id': 'a',
        'goal': 'Check CI',
      };

      controller.applyEvent(ThreadEventType.message, payload);
      controller.applyEvent(ThreadEventType.message, payload);

      expect(controller.liveMessages.single.text, '2 of 5 jobs fail');
    });
  });

  group('continue', () {
    test('a dispatched follow-up runs the same thread again', () async {
      final gateway = FakeThreadsGateway(support: ThreadSupport.full)
        ..continueResult = const ThreadContinueResult(
          status: ThreadContinueStatus.dispatched,
          delegationId: 'deleg_2',
          childSessionId: 'child-2',
        );
      final controller = _controller(gateway);
      controller.applyEvent(ThreadEventType.start, _event('a'));
      controller.applyEvent(
        ThreadEventType.complete,
        _event('a', extra: {'status': 'completed'}),
      );

      final result = await controller.continueThread('a', ' Shorter ');

      expect(gateway.calls, contains('continue a|Shorter'));
      expect(result.status, ThreadContinueStatus.dispatched);
      final thread = controller.thread('a')!;
      expect(thread.state, AgentThreadState.running);
      expect(thread.childSessionId, 'child-2');
      expect(thread.delegationId, 'deleg_2');
    });

    test('with every slot in use the follow-up is queued', () async {
      final gateway = FakeThreadsGateway(support: ThreadSupport.full)
        ..continueResult = const ThreadContinueResult(
          status: ThreadContinueStatus.queued,
          position: 2,
        );
      final controller = _controller(gateway);
      controller.applyEvent(ThreadEventType.start, _event('a'));
      controller.applyEvent(
        ThreadEventType.complete,
        _event('a', extra: {'status': 'completed'}),
      );

      await controller.continueThread('a', 'Shorter');

      expect(controller.thread('a')!.state, AgentThreadState.queued);
      expect(controller.queuePosition('a'), 2);

      // It starts by itself when a slot frees.
      controller.applyEvent(ThreadEventType.start, _event('a'));
      expect(controller.thread('a')!.state, AgentThreadState.running);
      expect(controller.queuePosition('a'), isNull);
    });

    test('a refused follow-up leaves the thread as it was', () async {
      final gateway = FakeThreadsGateway(support: ThreadSupport.full)
        ..continueResult = const ThreadContinueResult(
          status: ThreadContinueStatus.rejected,
          error: 'Delegation spawning is paused.',
        );
      final controller = _controller(gateway);
      controller.applyEvent(ThreadEventType.start, _event('a'));
      controller.applyEvent(
        ThreadEventType.complete,
        _event('a', extra: {'status': 'completed'}),
      );

      final result = await controller.continueThread('a', 'Shorter');

      expect(result.error, 'Delegation spawning is paused.');
      expect(controller.thread('a')!.state, AgentThreadState.done);
    });
  });
}
