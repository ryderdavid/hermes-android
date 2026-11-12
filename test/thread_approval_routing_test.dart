// A thread's approval travels the parent session's normal approval channel
// with the thread's id and goal added. Over a real loopback socket: the
// request reaches the parent chat's listener naming the thread, and the
// answer resolves that request only. No widget binding (real WS traffic).
import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/models/gateway_approval.dart';
import 'package:hermes_android/core/services/desktop_gateway_client.dart';
import 'package:hermes_android/core/services/ws_client.dart';

import 'support/fake_thread_gateway.dart';

void main() {
  late FakeThreadGateway gateway;
  late DesktopGatewayClient client;
  late List<(String, StreamEvent)> events;

  setUp(() async {
    gateway = await FakeThreadGateway.start();
    addTearDown(gateway.stop);
    client = DesktopGatewayClient.fromConnection(gateway.connection());
    addTearDown(client.close);
    events = [];
    client.setAsyncEventListener(
      (mobileSessionId, event) => events.add((mobileSessionId, event)),
    );
    await client.ensureSession('mobile-1');
  });

  StreamEvent approval(int index) => [
    for (final (_, event) in events)
      if (event.type == 'approval.request') event,
  ][index];

  test('the request reaches the parent chat and names the thread', () async {
    gateway.sendServerRequest(
      id: 'srq-thread',
      method: 'approval',
      params: {
        'request_id': 'f3a9',
        'command': 'gh run rerun 18734 --failed',
        'description': 'Re-run the failing Android jobs.',
        'choices': ['once', 'session', 'always', 'deny'],
        'subagent_id': 'sa-0-1a2b3c4d',
        'goal': 'Check CI matrix',
      },
    );
    await waitFor(() => events.isNotEmpty);

    // Delivered to the parent chat's session, not to some thread session.
    expect(events.single.$1, 'mobile-1');
    final request = GatewayApprovalRequest.fromEventData(approval(0).data);
    expect(request.thread?.subagentId, 'sa-0-1a2b3c4d');
    expect(request.thread?.goal, 'Check CI matrix');
    expect(request.command, 'gh run rerun 18734 --failed');
  });

  test('the main agent\'s own approval names no thread', () async {
    gateway.sendServerRequest(
      id: 'srq-main',
      method: 'approval',
      params: {'command': 'rm file', 'description': 'Delete a file'},
    );
    await waitFor(() => events.isNotEmpty);

    final request = GatewayApprovalRequest.fromEventData(approval(0).data);
    expect(request.thread, isNull);
  });

  test('the answer goes back to that thread\'s request only', () async {
    gateway.sendServerRequest(
      id: 'srq-thread',
      method: 'approval',
      params: {
        'command': 'gh run rerun 18734 --failed',
        'subagent_id': 'sa-0',
        'goal': 'Check CI matrix',
      },
    );
    await waitFor(() => events.isNotEmpty);
    final threadRequestId = approval(0).data['server_request_id'] as String;
    expect(
      client.ownsApprovalRequest('mobile-1', requestId: threadRequestId),
      isTrue,
    );

    await client.respondToApproval(
      sessionId: 'mobile-1',
      choice: 'once',
      serverRequestId: threadRequestId,
    );
    await waitFor(() => gateway.serverResponses.containsKey('srq-thread'));

    expect(gateway.serverResponses['srq-thread']?['result'], {
      'choice': 'once',
    });
    expect(gateway.serverResponses.keys, ['srq-thread']);
    expect(
      client.ownsApprovalRequest('mobile-1', requestId: threadRequestId),
      isFalse,
    );

    // A second thread's approval is its own request with its own answer.
    gateway.sendServerRequest(
      id: 'srq-other',
      method: 'approval',
      params: {
        'command': 'rm -rf build',
        'subagent_id': 'sa-1',
        'goal': 'Audit dependency licences',
      },
    );
    await waitFor(() => events.length == 2);
    final otherRequestId = approval(1).data['server_request_id'] as String;
    expect(otherRequestId, isNot(threadRequestId));
    expect(
      GatewayApprovalRequest.fromEventData(approval(1).data).thread?.goal,
      'Audit dependency licences',
    );

    // The answered request cannot be answered again.
    await expectLater(
      client.respondToApproval(
        sessionId: 'mobile-1',
        choice: 'deny',
        serverRequestId: threadRequestId,
      ),
      throwsStateError,
    );
    expect(gateway.serverResponses.containsKey('srq-other'), isFalse);

    await client.respondToApproval(
      sessionId: 'mobile-1',
      choice: 'deny',
      serverRequestId: otherRequestId,
    );
    await waitFor(() => gateway.serverResponses.containsKey('srq-other'));
    expect(gateway.serverResponses['srq-other']?['result'], {'choice': 'deny'});
    expect(gateway.serverResponses['srq-thread']?['result'], {
      'choice': 'once',
    });
  });
}
