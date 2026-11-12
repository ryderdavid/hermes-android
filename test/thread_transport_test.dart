// Thread transport over a real loopback socket: the WsClient wrappers, the
// capability probe, and event routing through DesktopGatewayClient. No
// widget binding: real WS traffic cannot share a suite with it.
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/services/desktop_gateway_client.dart';
import 'package:hermes_android/core/services/thread_wire.dart';
import 'package:hermes_android/core/services/ws_client.dart';

import 'support/fake_thread_gateway.dart';

Future<(FakeThreadGateway, WsClient)> _connected() async {
  final gateway = await FakeThreadGateway.start();
  addTearDown(gateway.stop);
  final client = WsClient(
    'http://127.0.0.1:${gateway.port}',
    token: 'fixture-key',
    heartbeatInterval: const Duration(hours: 1),
    heartbeatDeadline: const Duration(hours: 2),
  );
  addTearDown(client.close);
  await client.connect().timeout(const Duration(seconds: 5));
  return (gateway, client);
}

void main() {
  group('WsClient thread wrappers', () {
    test('subagent.list parses threads, failures and queued rows', () async {
      final (gateway, client) = await _connected();
      gateway.handlers[ThreadRpc.list] = (_) => rpcResult({
        'subagents': [
          {
            'subagent_id': 'sa-0-1a2b3c4d',
            'goal': 'Check the licences',
            'delegation_id': 'deleg_1',
            'model': 'sonnet',
            'started_at': 1767000000.0,
            'status': 'running',
            'tool_count': 7,
            'last_tool': 'terminal',
            'accepting_steer': true,
            'child_session_id': 'child-1',
            'pending_question': {
              'question_id': 'q_1',
              'text': 'Drop them?',
              'options': ['Drop', 'Flag'],
              'asked_at': 1767000100.0,
              'expires_at': 1767001000.0,
            },
          },
        ],
        'delegations': [
          {
            'delegation_id': 'deleg_0',
            'task_index': 1,
            'status': 'failed',
            'goal': 'Old task',
            'error': 'boom',
          },
        ],
        'queued': [
          {
            'subagent_id': 'sa-1',
            'goal': 'Draft notes',
            'queued_at': 1767000200.0,
          },
        ],
      });

      final roster = await client.listSubagents('runtime-1');

      expect(gateway.requestsFor(ThreadRpc.list).single['params'], {
        'session_id': 'runtime-1',
      });
      final thread = roster.threads.single;
      expect(thread.subagentId, 'sa-0-1a2b3c4d');
      expect(thread.goal, 'Check the licences');
      expect(thread.toolCount, 7);
      expect(thread.acceptingSteer, isTrue);
      expect(thread.childSessionId, 'child-1');
      expect(thread.pendingQuestion?.questionId, 'q_1');
      expect(thread.pendingQuestion?.options, ['Drop', 'Flag']);
      expect(roster.failed.single.goal, 'Old task');
      expect(roster.queued.single.subagentId, 'sa-1');
    });

    test('tail, steer and interrupt send the thread id', () async {
      final (gateway, client) = await _connected();
      gateway.handlers[ThreadRpc.tail] = (_) => rpcResult({
        'subagent_id': 'sa-1',
        'available': true,
        'text': '10:00:00 tool     | -> terminal(ls)\n',
        'truncated': true,
      });
      gateway.handlers[ThreadRpc.steer] = (params) => rpcResult({
        'status': 'queued',
        'subagent_id': params['subagent_id'],
        'text': params['text'],
      });
      gateway.handlers[ThreadRpc.interrupt] = (params) =>
          rpcResult({'found': true, 'subagent_id': params['subagent_id']});

      final tail = await client.tailSubagent(
        sessionId: 'runtime-1',
        subagentId: 'sa-1',
      );
      final steer = await client.steerSubagent(
        sessionId: 'runtime-1',
        subagentId: 'sa-1',
        text: 'Skip dev-only dependencies',
      );
      final stop = await client.interruptSubagent(
        sessionId: 'runtime-1',
        subagentId: 'sa-1',
      );

      expect(tail.available, isTrue);
      expect(tail.truncated, isTrue);
      expect(
        ThreadTailLine.parseAll(tail.text).single.toolStart?.name,
        'terminal',
      );
      expect(steer.queued, isTrue);
      expect(stop.found, isTrue);
      expect(gateway.requestsFor(ThreadRpc.steer).single['params'], {
        'session_id': 'runtime-1',
        'subagent_id': 'sa-1',
        'text': 'Skip dev-only dependencies',
      });
      expect(gateway.requestsFor(ThreadRpc.interrupt).single['params'], {
        'session_id': 'runtime-1',
        'subagent_id': 'sa-1',
      });
    });

    test('a rejected steer is reported, not thrown', () async {
      final (gateway, client) = await _connected();
      gateway.handlers[ThreadRpc.steer] = (_) =>
          rpcResult({'status': 'rejected', 'subagent_id': 'sa-1', 'text': 'x'});

      final steer = await client.steerSubagent(
        sessionId: 'runtime-1',
        subagentId: 'sa-1',
        text: 'x',
      );

      expect(steer.queued, isFalse);
    });

    test('delegation.status and delegation.pause', () async {
      final (gateway, client) = await _connected();
      gateway.handlers[ThreadRpc.delegationStatus] = (_) => rpcResult({
        'active': [
          {'subagent_id': 'a', 'depth': 0, 'model': 'sonnet'},
          {'subagent_id': 'b', 'depth': 0},
          {'subagent_id': 'b-child', 'depth': 1},
        ],
        'paused': false,
        'max_spawn_depth': 2,
        'max_concurrent_children': 3,
      });
      gateway.handlers[ThreadRpc.delegationPause] = (params) =>
          rpcResult({'paused': params['paused']});

      final status = await client.delegationStatus();
      final paused = await client.setDelegationPaused(true);

      // Nested children do not hold a background slot.
      expect(status.activeCount, 2);
      expect(status.maxConcurrent, 3);
      expect(status.paused, isFalse);
      expect(status.model, 'sonnet');
      expect(paused, isTrue);
      expect(gateway.requestsFor(ThreadRpc.delegationPause).single['params'], {
        'paused': true,
      });
    });

    test('a gateway error surfaces as a JsonRpcError with its code', () async {
      final (gateway, client) = await _connected();
      gateway.handlers[ThreadRpc.list] = (_) =>
          rpcError(4001, 'session not found or not owned by this transport');

      await expectLater(
        client.listSubagents('gone'),
        throwsA(
          isA<JsonRpcError>()
              .having((e) => e.code, 'code', 4001)
              .having((e) => e.method, 'method', ThreadRpc.list)
              .having((e) => e.message, 'message', contains('not found')),
        ),
      );
    });

    test('an unknown method surfaces as -32601 for every wrapper', () async {
      final (_, client) = await _connected();
      final calls = <String, Future<Object?> Function()>{
        ThreadRpc.list: () => client.listSubagents('s'),
        ThreadRpc.roster: client.subagentRoster,
        ThreadRpc.tail: () =>
            client.tailSubagent(sessionId: 's', subagentId: 'a'),
        ThreadRpc.steer: () =>
            client.steerSubagent(sessionId: 's', subagentId: 'a', text: 't'),
        ThreadRpc.interrupt: () =>
            client.interruptSubagent(sessionId: 's', subagentId: 'a'),
        ThreadRpc.delegationStatus: client.delegationStatus,
        ThreadRpc.delegationPause: () => client.setDelegationPaused(true),
        ThreadRpc.sessionModeSet: () =>
            client.setCoordinatorMode(sessionId: 's', coordinator: true),
        ThreadRpc.reply: () => client.replyToSubagent(
          sessionId: 's',
          subagentId: 'a',
          questionId: 'q',
          text: 't',
        ),
        ThreadRpc.continueThread: () =>
            client.continueSubagent(sessionId: 's', subagentId: 'a', text: 't'),
      };
      for (final entry in calls.entries) {
        await expectLater(
          entry.value(),
          throwsA(
            isA<JsonRpcError>()
                .having((e) => e.code, 'code', -32601)
                .having((e) => e.method, 'method', entry.key),
          ),
          reason: entry.key,
        );
      }
    });

    test('a response without a result object is an error', () async {
      final (gateway, client) = await _connected();
      for (final method in [
        ThreadRpc.list,
        ThreadRpc.tail,
        ThreadRpc.steer,
        ThreadRpc.interrupt,
        ThreadRpc.delegationStatus,
        ThreadRpc.delegationPause,
      ]) {
        // A reply with neither `result` nor `error`.
        gateway.handlers[method] = (_) => <String, dynamic>{};
      }
      final calls = <Future<Object?> Function()>[
        () => client.listSubagents('s'),
        () => client.tailSubagent(sessionId: 's', subagentId: 'a'),
        () => client.steerSubagent(sessionId: 's', subagentId: 'a', text: 't'),
        () => client.interruptSubagent(sessionId: 's', subagentId: 'a'),
        client.delegationStatus,
        () => client.setDelegationPaused(true),
      ];
      for (final call in calls) {
        await expectLater(
          call(),
          throwsA(
            isA<JsonRpcError>().having(
              (e) => e.message,
              'message',
              contains('no result'),
            ),
          ),
        );
      }
    });

    test('session.mode.set, subagent.reply and subagent.continue', () async {
      final (gateway, client) = await _connected();
      gateway.handlers[ThreadRpc.sessionModeSet] = (params) =>
          rpcResult({'coordinator': params['coordinator'], 'pending': true});
      gateway.handlers[ThreadRpc.reply] = (params) => rpcResult({
        'accepted': true,
        'subagent_id': params['subagent_id'],
        'question_id': params['question_id'],
        'answered_by': params['answered_by'],
      });
      gateway.handlers[ThreadRpc.continueThread] = (_) =>
          rpcResult({'status': 'queued', 'subagent_id': 'sa-1', 'position': 2});

      final mode = await client.setCoordinatorMode(
        sessionId: 'runtime-1',
        coordinator: true,
      );
      await client.replyToSubagent(
        sessionId: 'runtime-1',
        subagentId: 'sa-1',
        questionId: 'q_1',
        text: 'Flag them for legal',
      );
      final followUp = await client.continueSubagent(
        sessionId: 'runtime-1',
        subagentId: 'sa-1',
        text: 'Shorter',
      );

      expect(mode.coordinator, isTrue);
      expect(mode.pending, isTrue);
      expect(gateway.requestsFor(ThreadRpc.sessionModeSet).single['params'], {
        'session_id': 'runtime-1',
        'coordinator': true,
      });
      expect(gateway.requestsFor(ThreadRpc.reply).single['params'], {
        'session_id': 'runtime-1',
        'subagent_id': 'sa-1',
        'question_id': 'q_1',
        'text': 'Flag them for legal',
        'answered_by': 'user',
      });
      expect(followUp.status, ThreadContinueStatus.queued);
      expect(followUp.position, 2);
    });

    test('a closed question is rejected with the gateway code', () async {
      final (gateway, client) = await _connected();
      gateway.handlers[ThreadRpc.reply] = (_) => rpcError(
        ThreadReplyWire.closedCode,
        'Question q_1 is closed: it was already answered by the user.',
      );

      await expectLater(
        client.replyToSubagent(
          sessionId: 's',
          subagentId: 'sa-1',
          questionId: 'q_1',
          text: 'again',
        ),
        throwsA(
          isA<JsonRpcError>().having(
            (e) => e.code,
            'code',
            ThreadReplyWire.closedCode,
          ),
        ),
      );
    });
  });

  group('DesktopGatewayClient thread capabilities', () {
    test('reads advertised keys from the session bind', () async {
      final gateway = await FakeThreadGateway.start();
      addTearDown(gateway.stop);
      gateway.sessionInfo = {
        'coordinator_mode': false,
        'capabilities': ThreadCapabilityKey.all.toList(),
      };
      final client = DesktopGatewayClient.fromConnection(gateway.connection());
      addTearDown(client.close);

      await client.ensureSession('mobile-1');
      await client.probeThreadSupport();

      final caps = client.capabilities;
      expect(caps.threadsRoster, isTrue);
      expect(caps.threadsSteer, isTrue);
      expect(caps.threadsMessages, isTrue);
      expect(caps.threadsContinue, isTrue);
      expect(caps.threadsApprovals, isTrue);
      expect(caps.coordinatorMode, isTrue);
      // Advertised support needs no probe.
      expect(gateway.requestsFor(ThreadRpc.roster), isEmpty);
    });

    test('reads keys from a session.info event', () async {
      final gateway = await FakeThreadGateway.start();
      addTearDown(gateway.stop);
      final client = DesktopGatewayClient.fromConnection(gateway.connection());
      addTearDown(client.close);
      await client.ensureSession('mobile-1');
      expect(client.capabilities.coordinatorMode, isFalse);

      gateway.sendEvent(ThreadEventType.sessionInfo, {
        'coordinator_mode': true,
        'capabilities': [ThreadCapabilityKey.coordinatorMode],
      });

      await waitFor(() => client.capabilities.coordinatorMode);
      expect(client.capabilities.threadsMessages, isFalse);
    });

    test(
      'stock gateway: one successful probe enables roster and steer',
      () async {
        final gateway = await FakeThreadGateway.start();
        addTearDown(gateway.stop);
        gateway.handlers[ThreadRpc.roster] = (_) => rpcResult({'sessions': []});
        final client = DesktopGatewayClient.fromConnection(
          gateway.connection(),
        );
        addTearDown(client.close);
        await client.ensureSession('mobile-1');
        expect(client.capabilities.threadsRoster, isFalse);

        await client.probeThreadSupport();
        await client.probeThreadSupport();

        expect(gateway.requestsFor(ThreadRpc.roster), hasLength(1));
        expect(client.capabilities.threadsRoster, isTrue);
        expect(client.capabilities.threadsSteer, isTrue);
        // What only the updated gateway serves stays off.
        expect(client.capabilities.threadsMessages, isFalse);
        expect(client.capabilities.threadsContinue, isFalse);
        expect(client.capabilities.threadsApprovals, isFalse);
        expect(client.capabilities.coordinatorMode, isFalse);
      },
    );

    test(
      'a failed probe keeps thread support off and is not repeated',
      () async {
        final gateway = await FakeThreadGateway.start();
        addTearDown(gateway.stop);
        final client = DesktopGatewayClient.fromConnection(
          gateway.connection(),
        );
        addTearDown(client.close);
        await client.ensureSession('mobile-1');

        await client.probeThreadSupport();
        await client.probeThreadSupport();

        expect(gateway.requestsFor(ThreadRpc.roster), hasLength(1));
        expect(client.capabilities.threadsRoster, isFalse);
        expect(client.capabilities.threadsSteer, isFalse);
      },
    );

    test('a reconnect probes again and can find an upgraded gateway', () async {
      final gateway = await FakeThreadGateway.start();
      addTearDown(gateway.stop);
      final client = DesktopGatewayClient.fromConnection(gateway.connection());
      addTearDown(client.close);
      await client.ensureSession('mobile-1');
      await client.probeThreadSupport();
      expect(client.capabilities.threadsRoster, isFalse);

      // The gateway restarts with thread support.
      gateway.handlers[ThreadRpc.roster] = (_) => rpcResult({'sessions': []});
      await gateway.dropSockets();
      await waitFor(() => gateway.connectionCount >= 2);
      await client.ensureSession('mobile-1');
      await client.probeThreadSupport();

      expect(gateway.requestsFor(ThreadRpc.roster), hasLength(2));
      expect(client.capabilities.threadsRoster, isTrue);
    });
  });

  group('DesktopGatewayClient thread events', () {
    test(
      'subagent events reach the listener, also after a reconnect',
      () async {
        final gateway = await FakeThreadGateway.start();
        addTearDown(gateway.stop);
        final client = DesktopGatewayClient.fromConnection(
          gateway.connection(),
        );
        addTearDown(client.close);
        final events = <(String, StreamEvent)>[];
        client.setAsyncEventListener(
          (mobileSessionId, event) => events.add((mobileSessionId, event)),
        );
        await client.ensureSession('mobile-1');

        const types = [
          ThreadEventType.spawnRequested,
          ThreadEventType.start,
          ThreadEventType.tool,
          ThreadEventType.complete,
          ThreadEventType.message,
          ThreadEventType.question,
        ];
        for (final type in types) {
          gateway.sendEvent(type, {'subagent_id': 'sa-1', 'goal': 'Audit'});
        }
        await waitFor(() => events.length == types.length);
        expect([for (final (_, event) in events) event.type], types);
        expect({for (final (id, _) in events) id}, {'mobile-1'});

        // The socket drops; the client reconnects and re-binds by itself.
        events.clear();
        final firstRuntime = gateway.lastRuntimeSessionId;
        await gateway.dropSockets();
        await waitFor(
          () =>
              gateway.connectionCount >= 2 &&
              gateway.lastRuntimeSessionId != firstRuntime,
        );
        await client.ensureSession('mobile-1');

        gateway.sendEvent(ThreadEventType.start, {
          'subagent_id': 'sa-2',
          'goal': 'Draft release notes',
        });
        gateway.sendEvent(ThreadEventType.complete, {
          'subagent_id': 'sa-2',
          'goal': 'Draft release notes',
          'status': 'completed',
        });

        await waitFor(() => events.length == 2);
        expect(events.first.$1, 'mobile-1');
        expect(events.first.$2.type, ThreadEventType.start);
        expect(events.first.$2.data['subagent_id'], 'sa-2');
        expect(events.last.$2.type, ThreadEventType.complete);
      },
    );

    test('session.info is not forwarded as a chat event', () async {
      final gateway = await FakeThreadGateway.start();
      addTearDown(gateway.stop);
      final client = DesktopGatewayClient.fromConnection(gateway.connection());
      addTearDown(client.close);
      final events = <StreamEvent>[];
      client.setAsyncEventListener((_, event) => events.add(event));
      await client.ensureSession('mobile-1');

      gateway.sendEvent(ThreadEventType.sessionInfo, {
        'capabilities': [ThreadCapabilityKey.roster],
      });
      gateway.sendEvent(ThreadEventType.start, {'subagent_id': 'sa-1'});

      await waitFor(() => events.isNotEmpty);
      expect(events.single.type, ThreadEventType.start);
      expect(client.capabilities.threadsRoster, isTrue);
    });
  });
}
