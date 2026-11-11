import '../utils/tool_activity_summary.dart';

enum GatewayToolActivityPhase {
  running,
  generating,
  progress,
  completed,
  failed,
}

/// Whether a tool time is a device-side observation or a durable result row.
enum GatewayToolTimeSource { observed, storedResult }

/// Most recent evidenced time within a group, irrespective of row order.
GatewayToolActivity? latestKnownToolActivity(
  Iterable<GatewayToolActivity> activities,
) {
  GatewayToolActivity? latest;
  for (final activity in activities) {
    final at = activity.lastActivityAt;
    if (at != null &&
        (latest?.lastActivityAt == null ||
            !at.isBefore(latest!.lastActivityAt!))) {
      latest = activity;
    }
  }
  return latest;
}

class GatewayToolActivity {
  static const _maxNameLength = 120;
  static const _maxDetailLength = 500;
  static const _maxSummaryLength = 120;
  static int _nextLocalIdentity = 0;

  final String? toolId;

  /// Stable across merge updates, even if the gateway supplies a tool id later.
  /// Stored tool rows can also anchor the projected group to their message id.
  /// Unanchored activities get a unique local id, not another run's name.
  final String identity;
  final String name;
  final GatewayToolActivityPhase phase;
  final String? detail;

  /// Semantic "what the call is acting on", phrased client-side from the tool
  /// args (e.g. "lib/core/theme/hermes_theme.dart"). Rendered next to the tool
  /// name: "Read file: lib/core/theme/hermes_theme.dart".
  final String? summary;
  final double? durationSeconds;
  final String? emoji;

  /// Only set when a live start event was actually observed. A persisted tool
  /// result never establishes when the call started.
  final DateTime? startedAt;
  final DateTime? lastActivityAt;
  final GatewayToolTimeSource? lastActivityTimeSource;

  /// Where a live call sits among the chat's messages: the index of the last
  /// message that renders something (a user message, a stored tool result,
  /// or an assistant message with text or reasoning) when the call started.
  /// The chat places the call's row after that message until the server has
  /// stored the result, after which the stored order applies. `null` for
  /// stored calls and for calls with no known position.
  final int? anchorMessageIndex;

  GatewayToolActivity({
    required this.name,
    required this.phase,
    this.toolId,
    String? identity,
    this.detail,
    this.summary,
    this.durationSeconds,
    this.emoji,
    this.startedAt,
    this.lastActivityAt,
    this.lastActivityTimeSource,
    this.anchorMessageIndex,
  }) : identity =
           identity ??
           (toolId != null && toolId.trim().isNotEmpty
               ? 'tool:$toolId'
               : 'local:${_nextLocalIdentity++}');

  bool get isTerminal =>
      phase == GatewayToolActivityPhase.completed ||
      phase == GatewayToolActivityPhase.failed;

  bool get isFailed => phase == GatewayToolActivityPhase.failed;

  String get displayName => displayNameOf(name);

  /// A tool's raw name as words: `read_file` becomes "Read file".
  static String displayNameOf(String name) {
    final words = name.replaceAll(RegExp(r'[_-]+'), ' ').trim();
    if (words.isEmpty) return 'Tool';
    return words[0].toUpperCase() + words.substring(1);
  }

  /// The row's title line: the tool name plus its semantic summary, e.g.
  /// "Read file: lib/core/theme/hermes_theme.dart".
  String get displayTitle =>
      summary == null ? displayName : '$displayName: $summary';

  String get statusLabel {
    switch (phase) {
      case GatewayToolActivityPhase.running:
        return 'Running';
      case GatewayToolActivityPhase.generating:
        return 'Preparing';
      case GatewayToolActivityPhase.progress:
        return 'Working';
      case GatewayToolActivityPhase.completed:
        return durationSeconds == null
            ? 'Completed'
            : 'Completed in ${_formatDuration(durationSeconds!)}';
      case GatewayToolActivityPhase.failed:
        return durationSeconds == null
            ? 'Failed'
            : 'Failed after ${_formatDuration(durationSeconds!)}';
    }
  }

  static GatewayToolActivity? fromGatewayEvent(
    String eventType,
    Map<String, dynamic> data, {
    DateTime? observedAt,
  }) {
    if (!eventType.startsWith('tool.')) return null;

    final toolId = _firstText(data, const [
      'tool_id',
      'toolCallId',
      'tool_call_id',
      'id',
    ]);
    final rawName = _firstText(data, const ['name', 'tool', 'label']) ?? 'tool';
    final name = _normalizeText(rawName, _maxNameLength) ?? 'tool';
    final durationSeconds = _duration(data['duration_s']);
    final error = _normalizeText(
      _firstText(data, const ['error']),
      _maxDetailLength,
    );

    final phase = _phaseFor(eventType, data['status']?.toString(), error);
    final detail = switch (phase) {
      GatewayToolActivityPhase.failed => error,
      GatewayToolActivityPhase.completed => _normalizeText(
        _firstText(data, const ['summary']),
        _maxDetailLength,
      ),
      GatewayToolActivityPhase.progress => _normalizeText(
        _firstText(data, const ['preview', 'detail']),
        _maxDetailLength,
      ),
      GatewayToolActivityPhase.generating => _normalizeText(
        _firstText(data, const ['preview', 'detail']),
        _maxDetailLength,
      ),
      GatewayToolActivityPhase.running => _normalizeText(
        _firstText(data, const ['context', 'detail']),
        _maxDetailLength,
      ),
    };

    // The summary is phrased from the raw args when the gateway ships them
    // (WS tool.start/tool.complete and stored rows). On the REST streaming
    // path only a redacted `label` preview arrives — use it, unless it is just
    // the tool name again. `context` is deliberately not a fallback here: on
    // the WS path it is already the row's [detail] line.
    final args = data['args'] is Map
        ? (data['args'] as Map).cast<String, dynamic>()
        : null;
    final labelPreview = _normalizeText(
      _firstText(data, const ['label']),
      _maxSummaryLength,
    );
    final labelSummary =
        labelPreview != null && labelPreview.toLowerCase() != name.toLowerCase()
        ? previewSummary(name, labelPreview)
        : null;
    final summary = toolActivitySummary(name, args) ?? labelSummary;

    return GatewayToolActivity(
      toolId: toolId,
      name: name,
      phase: phase,
      detail: detail,
      summary: summary,
      durationSeconds: durationSeconds,
      emoji: _normalizeText(_firstText(data, const ['emoji']), 8),
      startedAt:
          eventType == 'tool.start' && phase == GatewayToolActivityPhase.running
          ? observedAt
          : null,
      lastActivityAt: observedAt,
      lastActivityTimeSource: observedAt == null
          ? null
          : GatewayToolTimeSource.observed,
    );
  }

  /// API message timestamps are Unix seconds (possibly fractional), not the
  /// time this device fetched the history. Missing/invalid values stay unknown.
  static DateTime? storedResultTime(dynamic timestamp) {
    if (timestamp is! num || !timestamp.isFinite || timestamp <= 0) {
      return null;
    }
    try {
      return DateTime.fromMillisecondsSinceEpoch(
        (timestamp * 1000).round(),
        isUtc: true,
      );
    } on RangeError {
      return null;
    }
  }

  factory GatewayToolActivity.fromStoredResult({
    required String name,
    String? toolId,
    required dynamic timestamp,
    DateTime? observedStart,
    DateTime? observedLastActivity,
    Map<String, dynamic>? args,
    String? contextPreview,
  }) {
    final resultTime = storedResultTime(timestamp);
    return GatewayToolActivity(
      name: name,
      toolId: toolId,
      phase: GatewayToolActivityPhase.completed,
      summary:
          toolActivitySummary(name, args) ??
          previewSummary(
            name,
            _normalizeText(contextPreview, _maxSummaryLength),
          ),
      startedAt: observedStart,
      lastActivityAt: resultTime ?? observedLastActivity,
      lastActivityTimeSource: resultTime != null
          ? GatewayToolTimeSource.storedResult
          : observedLastActivity != null
          ? GatewayToolTimeSource.observed
          : null,
    );
  }

  GatewayToolActivity merge(GatewayToolActivity update) {
    return GatewayToolActivity(
      toolId: update.toolId ?? toolId,
      identity: identity,
      name: update.name == 'tool' && name != 'tool' ? name : update.name,
      phase: update.phase,
      detail: update.detail ?? detail,
      summary: update.summary ?? summary,
      durationSeconds: update.durationSeconds ?? durationSeconds,
      emoji: update.emoji ?? emoji,
      startedAt: startedAt ?? update.startedAt,
      lastActivityAt: update.lastActivityAt ?? lastActivityAt,
      lastActivityTimeSource:
          update.lastActivityTimeSource ?? lastActivityTimeSource,
      anchorMessageIndex: anchorMessageIndex ?? update.anchorMessageIndex,
    );
  }

  /// This activity placed after message [index] of the chat.
  GatewayToolActivity anchoredAt(int? index) => GatewayToolActivity(
    toolId: toolId,
    identity: identity,
    name: name,
    phase: phase,
    detail: detail,
    summary: summary,
    durationSeconds: durationSeconds,
    emoji: emoji,
    startedAt: startedAt,
    lastActivityAt: lastActivityAt,
    lastActivityTimeSource: lastActivityTimeSource,
    anchorMessageIndex: index,
  );

  static GatewayToolActivityPhase _phaseFor(
    String eventType,
    String? legacyStatus,
    String? error,
  ) {
    if (eventType == 'tool.complete') {
      return error == null
          ? GatewayToolActivityPhase.completed
          : GatewayToolActivityPhase.failed;
    }
    if (eventType == 'tool.generating') {
      return GatewayToolActivityPhase.generating;
    }
    if (eventType == 'tool.progress') {
      return GatewayToolActivityPhase.progress;
    }

    switch (legacyStatus?.trim().toLowerCase()) {
      case 'completed':
      case 'complete':
      case 'finished':
      case 'done':
        return GatewayToolActivityPhase.completed;
      case 'failed':
      case 'error':
        return GatewayToolActivityPhase.failed;
      case 'generating':
      case 'preparing':
        return GatewayToolActivityPhase.generating;
      case 'progress':
      case 'working':
        return GatewayToolActivityPhase.progress;
      default:
        return GatewayToolActivityPhase.running;
    }
  }

  static String? _firstText(Map<String, dynamic> data, List<String> keys) {
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) return value;
    }
    return null;
  }

  static String? _normalizeText(String? value, int maxLength) {
    if (value == null) return null;
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return null;
    return normalized.length <= maxLength
        ? normalized
        : '${normalized.substring(0, maxLength - 1)}…';
  }

  static double? _duration(dynamic value) {
    if (value is num && value.isFinite && value >= 0) {
      return value.toDouble();
    }
    return null;
  }

  static String _formatDuration(double value) {
    if (value < 1) return '${(value * 1000).round()} ms';
    return '${value.toStringAsFixed(value < 10 ? 1 : 0)} s';
  }
}

class GatewayTurnStatus {
  static const _maxTextLength = 240;

  final String kind;
  final String text;

  const GatewayTurnStatus({required this.kind, required this.text});

  static GatewayTurnStatus? fromGatewayEvent(
    String eventType,
    Map<String, dynamic> data,
  ) {
    if (eventType != 'status.update' && eventType != 'thinking.delta') {
      return null;
    }

    final kind = eventType == 'thinking.delta'
        ? 'thinking'
        : _normalize(data['kind']?.toString(), 40) ?? 'status';
    final rawText = _normalize(data['text']?.toString(), _maxTextLength);
    final text = rawText ?? _fallbackText(kind);
    if (text == null) return null;
    return GatewayTurnStatus(kind: kind, text: text);
  }

  static String? _fallbackText(String kind) {
    switch (kind) {
      case 'compacting':
        return 'Compacting conversation context…';
      case 'compacted':
        return 'Conversation context compacted';
      default:
        return null;
    }
  }

  static String? _normalize(String? value, int maxLength) {
    if (value == null) return null;
    final normalized = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (normalized.isEmpty) return null;
    return normalized.length <= maxLength
        ? normalized
        : '${normalized.substring(0, maxLength - 1)}…';
  }
}
