/// Gateway capability discovery for the Hermes Android shell.
///
/// Phase 0 of `docs/ANDROID_DAILY_DRIVER_ROADMAP.md` requires every later
/// feature to be capability-aware rather than to assume the newest gateway.
/// The registry answers one question — *may I call this method?* — from three
/// sources, in increasing order of authority:
///
/// 1. the `gateway.ready` capability advertisement;
/// 2. a successful call (proof the method exists);
/// 3. an unknown-method error (proof it does not).
///
/// The central compatibility rule is that **silence is not a denial**. Older
/// gateways implement methods they never advertise, so an absent family yields
/// [CapabilitySupport.unknown] and the caller is expected to try the call and
/// report the outcome back through [recordSuccess] / [recordFailure]. Only a
/// real unknown-method response downgrades a method to
/// [CapabilitySupport.unsupported], which lets the UI show a calm compatibility
/// notice instead of an error.
library;

import 'package:flutter/foundation.dart';

import 'thread_wire.dart';
import 'ws_client.dart';

/// What the registry currently knows about one gateway method.
enum CapabilitySupport {
  /// Never advertised and never probed — the caller should try the call.
  unknown,

  /// Advertised in `gateway.ready`, or proven by a real response.
  supported,

  /// The gateway answered with an unknown-method error.
  unsupported,
}

/// Tracks which gateway methods the connected Hermes instance offers.
///
/// Extends [ChangeNotifier] so panes can rebuild when a probe changes a
/// verdict, and only notifies when a verdict actually changed to avoid UI
/// churn on repeated identical observations.
class CapabilityRegistry extends ChangeNotifier {
  static const _unknownMethodCode = -32601;

  /// Method prefixes that a differently named capability family covers.
  static const _familyAliases = <String, String>{'turn': 'turn_recovery'};

  String? _protocolName;
  int? _protocolMajor;
  final Map<String, Map<String, dynamic>> _advertised = {};
  final Map<String, CapabilitySupport> _probed = {};
  final Set<String> _sessionCapabilities = {};
  bool _threadRosterProbeStarted = false;
  int _connectionEpoch = 0;

  /// The protocol name from the last accepted `gateway.ready` frame.
  String? get protocolName => _protocolName;

  /// The protocol major version from the last accepted `gateway.ready` frame.
  int? get protocolMajor => _protocolMajor;

  /// Reads a `gateway.ready` frame, returning whether it was one.
  ///
  /// A frame of any other type is ignored rather than treated as an empty
  /// advertisement, so unrelated events cannot erase what we already know.
  bool ingestGatewayReady(Map<String, dynamic> frame) {
    if (frame['method'] != 'event') return false;
    final params = _stringMap(frame['params']);
    if (params == null || params['type'] != 'gateway.ready') return false;

    final payload = _stringMap(params['payload']);
    final protocol = _stringMap(payload?['protocol']);
    final capabilities = _stringMap(payload?['capabilities']);

    _protocolName = protocol?['name'] is String
        ? protocol!['name'] as String
        : null;
    _protocolMajor = protocol?['major'] is int
        ? protocol!['major'] as int
        : null;

    _advertised.clear();
    if (capabilities != null) {
      for (final entry in capabilities.entries) {
        final value = _stringMap(entry.value);
        if (value != null) _advertised[entry.key] = value;
      }
    }
    notifyListeners();
    return true;
  }

  /// Whether the ready frame advertised the [family] capability.
  bool advertises(String family) => _advertised.containsKey(family);

  /// Feeds this registry every `gateway.ready` frame [client] receives.
  ///
  /// Chains onto any existing `onGatewayReady` listener rather than replacing
  /// it, so binding the registry cannot silently break turn recovery or any
  /// other consumer of the same greeting.
  void bindTo(WsClient client) {
    final previous = client.onGatewayReady;
    client.onGatewayReady = (frame) {
      ingestGatewayReady(frame);
      previous?.call(frame);
    };
  }

  /// The raw advertisement for [family], or null when it was not advertised.
  Map<String, dynamic>? advertised(String family) => _advertised[family];

  /// The current verdict for a fully qualified method such as `projects.list`.
  CapabilitySupport supportFor(String method) {
    final probed = _probed[method];
    if (probed != null) return probed;
    return advertises(_familyOf(method))
        ? CapabilitySupport.supported
        : CapabilitySupport.unknown;
  }

  /// True only when the method is known to work. Unknown is not a yes.
  bool isSupported(String method) =>
      supportFor(method) == CapabilitySupport.supported;

  /// True only when the gateway proved the method missing. Unknown is not a no.
  bool isUnsupported(String method) =>
      supportFor(method) == CapabilitySupport.unsupported;

  /// Records that [method] returned a real result.
  void recordSuccess(String method) {
    _record(method, CapabilitySupport.supported);
  }

  /// Records the outcome of a failed call to [method].
  ///
  /// Only an unknown-method [JsonRpcError] means "missing". A gateway domain
  /// error proves the opposite — the method ran and rejected the request — but
  /// a locally synthesised transport failure (closed socket, timeout) means the
  /// gateway never answered at all, so the verdict stays unknown and a later
  /// reconnect can still discover support.
  void recordFailure(String method, Object error) {
    if (error is! JsonRpcError) return;
    if (_isUnknownMethod(error)) {
      _record(method, CapabilitySupport.unsupported);
      return;
    }
    if (_isTransportFailure(error)) return;
    _record(method, CapabilitySupport.supported);
  }

  /// Forgets everything, for a new connection or profile.
  void reset() {
    _protocolName = null;
    _protocolMajor = null;
    _advertised.clear();
    _probed.clear();
    _sessionCapabilities.clear();
    _threadRosterProbeStarted = false;
    _connectionEpoch += 1;
    notifyListeners();
  }

  // ── Threads and coordinator mode ───────────────────────────────────────
  //
  // These capabilities are advertised as a list of keys in `session.info`
  // rather than in `gateway.ready`. A stock gateway advertises none of them
  // but already serves the roster, tail, steer and interrupt RPCs, so thread
  // support there is proven by one `subagent.list` probe per connection.

  /// Reads the capability keys of a `session.info` object: the event
  /// payload, or the `info` of a session.create / session.resume result.
  ///
  /// An object without a `capabilities` list is a stock gateway's and leaves
  /// what is known untouched; only [reset] (a new connection) forgets keys.
  void ingestSessionInfo(Object? info) {
    final parsed = ThreadSessionInfo.parse(info);
    if (parsed == null || parsed.capabilities.isEmpty) return;
    final before = _sessionCapabilities.length;
    _sessionCapabilities.addAll(parsed.capabilities);
    if (_sessionCapabilities.length != before) notifyListeners();
  }

  /// Whether `session.info` advertised [key] on this connection.
  bool advertisesSessionCapability(String key) =>
      _sessionCapabilities.contains(key);

  bool get _threadRosterProbed => isSupported(ThreadRpc.list);

  /// The roster, tail, slot status and pause are available: advertised, or
  /// proven by the probe.
  bool get threadsRoster =>
      advertisesSessionCapability(ThreadCapabilityKey.roster) ||
      _threadRosterProbed;

  /// Steer and stop are available. A stock gateway that passes the roster
  /// probe serves both.
  bool get threadsSteer =>
      advertisesSessionCapability(ThreadCapabilityKey.steer) ||
      _threadRosterProbed;

  /// Thread updates and questions, and `subagent.reply`. Advertised only.
  bool get threadsMessages =>
      advertisesSessionCapability(ThreadCapabilityKey.messages);

  /// `subagent.continue`. Advertised only.
  bool get threadsContinue =>
      advertisesSessionCapability(ThreadCapabilityKey.continueThreads);

  /// Thread attribution on approval requests. Advertised only.
  bool get threadsApprovals =>
      advertisesSessionCapability(ThreadCapabilityKey.approvals);

  /// `session.mode.set`. Advertised only: the app never imitates it.
  bool get coordinatorMode =>
      advertisesSessionCapability(ThreadCapabilityKey.coordinatorMode);

  /// Probes `subagent.list` (the per-chat roster) once per connection on a
  /// gateway that has not advertised thread support. [call] performs the RPC.
  ///
  /// A result, or a domain error, proves the method exists. An unknown-method
  /// error proves it does not, and the app keeps the read-only task list. A
  /// transport failure proves nothing, so a later call may probe again.
  /// [reset] re-arms the probe for the next connection.
  Future<void> probeThreadRoster(Future<Object?> Function() call) async {
    if (_threadRosterProbeStarted ||
        advertisesSessionCapability(ThreadCapabilityKey.roster)) {
      return;
    }
    _threadRosterProbeStarted = true;
    final epoch = _connectionEpoch;
    try {
      await call();
      // An answer from a connection that has since been replaced says
      // nothing about the current one.
      if (epoch != _connectionEpoch) return;
      recordSuccess(ThreadRpc.list);
    } catch (error) {
      if (epoch != _connectionEpoch) return;
      recordFailure(ThreadRpc.list, error);
      if (supportFor(ThreadRpc.list) == CapabilitySupport.unknown) {
        _threadRosterProbeStarted = false;
      }
    }
  }

  void _record(String method, CapabilitySupport support) {
    if (_probed[method] == support) return;
    _probed[method] = support;
    notifyListeners();
  }

  static String _familyOf(String method) {
    final separator = method.indexOf('.');
    final prefix = separator < 0 ? method : method.substring(0, separator);
    return _familyAliases[prefix] ?? prefix;
  }

  static bool _isUnknownMethod(JsonRpcError error) {
    if (error.code == _unknownMethodCode) return true;
    final message = error.message.toLowerCase();
    return message.contains('unknown method') ||
        message.contains('method not found');
  }

  /// Whether the error was synthesised client-side because no reply arrived.
  ///
  /// These carry no gateway response, so they must never promote a method.
  static bool _isTransportFailure(JsonRpcError error) {
    if (error.reason == 'connection_closed' ||
        error.reason == 'gateway_ready_drift') {
      return true;
    }
    if (error.code != null) return false;
    final message = error.message.toLowerCase();
    return message.contains('timeout') ||
        message.contains('timed out') ||
        message.contains('connection closed') ||
        message.contains('not connected');
  }

  static Map<String, dynamic>? _stringMap(Object? value) =>
      value is Map ? Map<String, dynamic>.from(value) : null;
}
