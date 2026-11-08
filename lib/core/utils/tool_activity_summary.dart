/// Client-side semantic summary for a tool-use row.
///
/// The gateway ships full tool `args` on `tool.start` / `tool.complete` and on
/// stored tool messages, plus a redacted 80-char `context`/`label` preview.
/// This module phrases the card's `Tool name: <what>` label from the args,
/// so a row reads e.g. "Read file: lib/core/theme/hermes_theme.dart" or
/// "Terminal: flutter analyze" instead of just the tool name.
///
/// All output is derived from the call's own data — no new user-visible
/// literals, so nothing here needs the l10n catalogues.
library;

/// Longest summary rendered next to the tool name.
const int kToolSummaryMaxLength = 100;

/// Tool name -> the argument that says what the call is acting on. Mirrors the
/// gateway's primary-arg map (`_PRIMARY_ARGS` in agent/display.py).
const Map<String, String> _primaryArgKeys = {
  'terminal': 'command',
  'execute_code': 'code',
  'browser_exec': 'code',
  'web_search': 'query',
  'web_extract': 'urls',
  'read_file': 'path',
  'write_file': 'path',
  'patch': 'path',
  'search_files': 'pattern',
  'browser_navigate': 'url',
  'browser_click': 'ref',
  'browser_type': 'text',
  'image_generate': 'prompt',
  'video_generate': 'prompt',
  'text_to_speech': 'text',
  'vision_analyze': 'question',
  'skill_view': 'name',
  'skill_manage': 'name',
  'skills_list': 'category',
  'session_search': 'query',
  'cronjob_manage': 'action',
  'delegate_task': 'goal',
  'memory': 'target',
};

/// Checked in order when the tool has no curated primary key.
const List<String> _fallbackArgKeys = [
  'query',
  'text',
  'command',
  'path',
  'name',
  'prompt',
  'code',
  'goal',
  'url',
  'action',
];

/// Argument keys whose values must never appear in a summary: the gateway
/// redacts these in the `context`/`label` preview but ships raw `args`.
const List<String> _sensitiveSubstrings = [
  'password',
  'passwd',
  'secret',
  'token',
  'api_key',
  'apikey',
  'authorization',
  'credential',
  'private_key',
  'access_key',
];

bool _isSensitiveKey(String key) {
  final normalized = key.toLowerCase();
  return _sensitiveSubstrings.any(normalized.contains);
}

/// Builds the semantic summary for [name] called with [args], or null when the
/// call carries nothing worth summarizing.
String? toolActivitySummary(String name, Map<String, dynamic>? args) {
  if (args == null || args.isEmpty) return null;
  final tool = name.toLowerCase();

  // Tools whose primary argument is not the whole story.
  switch (tool) {
    case 'delegate_task':
      return _delegateTaskSummary(args);
    case 'clarify':
      return _clarifySummary(args);
  }

  final primary = _primaryArgKeys[tool];
  final candidates = [?primary, ..._fallbackArgKeys];
  for (final key in candidates) {
    if (_isSensitiveKey(key)) continue;
    final raw = args[key];
    if (raw == null) continue;
    final value = raw is List ? (raw.isNotEmpty ? raw.first : null) : raw;
    if (value == null) continue;
    final text = _oneline('$value');
    if (text.isEmpty) continue;
    // Paths and URLs read best tail-truncated (the file name is at the end);
    // everything else head-truncated (the command/verb is at the start).
    final keepTail = key == 'path' || key == 'url' || key == 'urls';
    return _clip(text, keepTail: keepTail);
  }
  return null;
}

String? _delegateTaskSummary(Map<String, dynamic> args) {
  final action = _oneline('${args['action'] ?? ''}').toLowerCase();
  if (action == 'list' || action == 'steer' || action == 'stop') {
    final id = _oneline('${args['subagent_id'] ?? ''}');
    return _clip(id.isEmpty ? action : '$action $id', keepTail: false);
  }
  final tasks = args['tasks'];
  if (tasks is List && tasks.isNotEmpty) {
    final first = tasks.first;
    if (first is Map && first['goal'] is String) {
      return _clip(_oneline(first['goal'] as String), keepTail: false);
    }
  }
  final goal = args['goal'];
  if (goal is String && goal.trim().isNotEmpty) {
    return _clip(_oneline(goal), keepTail: false);
  }
  return null;
}

String? _clarifySummary(Map<String, dynamic> args) {
  final questions = args['questions'];
  if (questions is List && questions.isNotEmpty) {
    final first = questions.first;
    if (first is Map && first['question'] is String) {
      return _clip(_oneline(first['question'] as String), keepTail: false);
    }
    if (first is String) return _clip(_oneline(first), keepTail: false);
  }
  return null;
}

String _oneline(String value) => value.replaceAll(RegExp(r'\s+'), ' ').trim();

String _clip(String text, {required bool keepTail}) {
  if (text.length <= kToolSummaryMaxLength) return text;
  const ellipsis = '…';
  if (keepTail) {
    return '$ellipsis${text.substring(text.length - kToolSummaryMaxLength + ellipsis.length)}';
  }
  return '${text.substring(0, kToolSummaryMaxLength - ellipsis.length)}$ellipsis';
}
