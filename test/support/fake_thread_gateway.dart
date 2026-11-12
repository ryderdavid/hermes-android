import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:hermes_android/core/models/connection.dart';

/// A reply to one JSON-RPC request: a `result` object, or an `error`.
typedef FakeRpcReply = Map<String, dynamic>;

FakeRpcReply rpcResult(Map<String, dynamic> result) => {'result': result};

FakeRpcReply rpcError(int code, String message) => {
  'error': {'code': code, 'message': message},
};

/// A local Hermes gateway for thread tests: dashboard auth, a WebSocket that
/// greets with `gateway.ready`, session bind, and scripted replies per method.
///
/// Real loopback traffic, so a suite using it must not initialise
/// `TestWidgetsFlutterBinding`.
class FakeThreadGateway {
  FakeThreadGateway._(this._server);

  final HttpServer _server;
  final List<WebSocket> _sockets = [];

  /// Scripted replies. A method without one answers `-32601`.
  final Map<String, FakeRpcReply Function(Map<String, dynamic> params)>
  handlers = {};

  /// Every request received, in order.
  final List<Map<String, dynamic>> requests = [];

  /// The `info` object returned by session.resume and session.create.
  Map<String, dynamic>? sessionInfo;

  int connectionCount = 0;
  int _runtimeCounter = 0;
  String? lastRuntimeSessionId;

  int get port => _server.port;

  SavedConnection connection({String id = 'thread-test'}) => SavedConnection(
    id: id,
    label: 'Local fixture',
    // A distinct host alias: a same-host override would fall back to the
    // dashboard port and bypass this server.
    host: 'localhost',
    port: port,
    apiKey: 'fixture-key',
    useHttps: false,
    desktopGatewayUrl: 'http://127.0.0.1:$port',
    dashboardUsername: 'user',
    dashboardPassword: 'pass',
  );

  List<Map<String, dynamic>> requestsFor(String method) => [
    for (final request in requests)
      if (request['method'] == method) request,
  ];

  static Future<FakeThreadGateway> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final gateway = FakeThreadGateway._(server);
    server.listen(gateway._handle);
    return gateway;
  }

  Future<void> _handle(HttpRequest request) async {
    if (request.method == 'POST' &&
        request.uri.path == '/auth/password-login') {
      request.response
        ..statusCode = 200
        ..headers.set('set-cookie', 'hermes_session_at=TOK123; Path=/')
        ..write('{"ok":true}');
      await request.response.close();
      return;
    }
    if (request.method == 'POST' && request.uri.path == '/api/auth/ws-ticket') {
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.json
        ..write('{"ticket":"TICKET-1"}');
      await request.response.close();
      return;
    }
    if (request.uri.path != '/api/ws') {
      request.response.statusCode = 404;
      await request.response.close();
      return;
    }
    final socket = await WebSocketTransformer.upgrade(request);
    _sockets.add(socket);
    connectionCount++;
    socket.add(
      jsonEncode({
        'jsonrpc': '2.0',
        'method': 'event',
        'params': {'type': 'gateway.ready', 'payload': <String, dynamic>{}},
      }),
    );
    socket.listen((raw) {
      final frame = jsonDecode(raw as String) as Map<String, dynamic>;
      final id = frame['id'];
      final method = frame['method'];
      if (method is! String) return;
      final params = frame['params'] is Map
          ? Map<String, dynamic>.from(frame['params'] as Map)
          : <String, dynamic>{};
      requests.add({'method': method, 'params': params});
      FakeRpcReply reply;
      final handler = handlers[method];
      if (handler != null) {
        reply = handler(params);
      } else if (method == 'gateway.ping' || method == 'client.capabilities') {
        reply = rpcResult({'ok': true});
      } else if (method == 'session.resume') {
        final requested = params['session_id']?.toString() ?? '';
        if (!requested.startsWith('stored-')) {
          reply = rpcError(4007, 'session not found');
        } else {
          lastRuntimeSessionId = 'runtime-${++_runtimeCounter}';
          reply = rpcResult({
            'session_id': lastRuntimeSessionId,
            'info': ?sessionInfo,
          });
        }
      } else if (method == 'session.create') {
        lastRuntimeSessionId = 'runtime-${++_runtimeCounter}';
        reply = rpcResult({
          'session_id': lastRuntimeSessionId,
          'stored_session_id': 'stored-1',
          'info': ?sessionInfo,
        });
      } else if (method == 'prompt.submit') {
        reply = rpcResult({'status': 'accepted'});
        final sessionId = params['session_id']?.toString();
        scheduleMicrotask(
          () => sendEvent('message.complete', {
            'text': 'ok',
          }, sessionId: sessionId),
        );
      } else {
        reply = rpcError(-32601, 'unknown method: $method');
      }
      socket.add(jsonEncode({'jsonrpc': '2.0', 'id': id, ...reply}));
    });
  }

  /// Pushes an event to every open socket.
  void sendEvent(
    String type,
    Map<String, dynamic> payload, {
    String? sessionId,
  }) {
    final frame = jsonEncode({
      'jsonrpc': '2.0',
      'method': 'event',
      'params': {
        'type': type,
        'session_id': sessionId ?? lastRuntimeSessionId,
        'payload': payload,
      },
    });
    for (final socket in _sockets) {
      socket.add(frame);
    }
  }

  /// Closes every socket from the server side, as a gateway restart would.
  Future<void> dropSockets() async {
    final sockets = List<WebSocket>.from(_sockets);
    _sockets.clear();
    for (final socket in sockets) {
      await socket.close(WebSocketStatus.goingAway, 'fixture drop');
    }
  }

  Future<void> stop() async {
    await dropSockets();
    await _server.close(force: true);
  }
}

/// Polls [condition] until it holds.
Future<void> waitFor(
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 8),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      throw StateError('condition not met within $timeout');
    }
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }
}
