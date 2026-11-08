/// Client-side semantic summary for a tool-use row.
///
/// The gateway ships full tool `args` on `tool.start` / `tool.complete` and on
/// stored tool messages, plus a redacted 80-char `context`/`label` preview.
/// This module phrases the card's `Tool name: <summary>` line from the args, so
/// a row reads e.g. "Patch: …/gateway_activity_card.dart" or
/// "Terminal: running the test suite" — a plain-language line about what the
/// call is doing, never a bare arcane command.
///
/// File-ish tools summarize to the object they act on (path/URL/pattern/query,
/// tail-truncated so the file name survives). `terminal`/`execute_code` map the
/// command to a plain sentence; the raw command stays visible in the row's
/// detail line. All output is derived from the call's own data plus fixed
/// English verb phrases (same precedent as the model's `statusLabel`), so
/// nothing here needs the l10n catalogues.
library;

/// Longest summary rendered next to the tool name.
const int kToolSummaryMaxLength = 80;

/// Tool name -> the argument that says what the call is acting on. Mirrors the
/// gateway's primary-arg map (`_PRIMARY_ARGS` in agent/display.py).
const Map<String, String> _primaryArgKeys = {
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
  'path',
  'name',
  'prompt',
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

  // Tools whose summary is a plain-language sentence, not their raw payload.
  switch (tool) {
    case 'terminal':
      final command = args['command'];
      if (command is! String || command.trim().isEmpty) return null;
      return commandSentence(command) ?? 'running a shell command';
    case 'execute_code':
      final code = args['code'];
      if (code is! String || code.trim().isEmpty) return null;
      return _leadingComment(code) ?? 'running code';
    case 'browser_exec':
      final code = args['code'];
      if (code is! String || code.trim().isEmpty) return null;
      return _leadingComment(code) ?? 'driving the browser';
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
    // everything else head-truncated.
    final keepTail = key == 'path' || key == 'url' || key == 'urls';
    return _clip(text, keepTail: keepTail);
  }
  return null;
}

/// Maps a gateway `context`/`label` preview to a summary when no raw args are
/// available (REST streaming frames, stored rows without args). Terminal
/// previews are command first-lines, so they get the same plain-sentence
/// mapping; everything else is used as-is.
String? previewSummary(String name, String? preview) {
  if (preview == null || preview.trim().isEmpty) return null;
  if (name.toLowerCase() == 'terminal') {
    return commandSentence(preview) ?? preview;
  }
  return preview;
}

/// Maps a shell command's first line to a plain-language sentence. Returns null
/// for unrecognized commands (the caller falls back to a generic phrase).
String? commandSentence(String command) {
  final firstLine = command
      .split('\n')
      .firstWhere((line) => line.trim().isNotEmpty, orElse: () => '');
  var parts = firstLine.trim().split(RegExp(r'\s+'));
  if (parts.isEmpty) return null;
  // `env VAR=… <bin> …` — look at the real binary, not `env`.
  if (parts[0].split('/').last == 'env' && parts.length > 1) {
    parts = parts.sublist(1);
    while (parts.isNotEmpty && parts[0].contains('=')) {
      parts = parts.sublist(1);
    }
  }
  if (parts.isEmpty) return null;
  final bin = parts[0].split('/').last; // strip any path prefix
  final rest = parts.length > 1 ? parts.sublist(1).join(' ') : '';
  switch (bin) {
    case 'flutter':
      if (rest.startsWith('test')) return 'running the test suite';
      if (rest.startsWith('analyze')) return 'checking the code for issues';
      if (rest.startsWith('build')) return 'building the app';
      if (rest.startsWith('pub')) return 'updating package dependencies';
      if (rest.startsWith('run')) return 'launching the app';
      if (rest.startsWith('doctor')) return 'checking the Flutter setup';
      return 'working with Flutter';
    case 'dart':
      if (rest.startsWith('format')) return 'formatting the code';
      return 'running Dart code';
    case 'git':
      if (rest.startsWith('commit')) return 'committing changes';
      if (rest.startsWith('push')) return 'pushing to the remote';
      if (RegExp(r'^(pull|rebase|merge|fetch)').hasMatch(rest)) {
        return 'syncing with the remote';
      }
      if (rest.startsWith('add')) return 'staging changes';
      if (RegExp(r'^(status|diff|log|show|branch)').hasMatch(rest)) {
        return 'reviewing the repo';
      }
      if (rest.startsWith('tag')) return 'tagging a release';
      if (rest.startsWith('checkout') || rest.startsWith('switch')) {
        return 'switching branches';
      }
      return 'working with git';
    case 'bd':
      return 'updating the issue tracker';
    case 'gh':
      return 'working with GitHub';
    case 'tailscale':
      return 'managing the Tailnet';
    case 'adb':
      return 'talking to the Android device';
    case 'python3':
    case 'python':
      return 'running a Python script';
    case 'ls':
    case 'cat':
    case 'grep':
    case 'rg':
    case 'sed':
    case 'find':
    case 'head':
    case 'tail':
    case 'wc':
      return 'inspecting files';
    case 'cp':
    case 'mv':
    case 'rm':
      return 'moving files around';
    case 'curl':
    case 'wget':
      return 'making an HTTP request';
    case 'ssh':
    case 'scp':
      return 'connecting over SSH';
    case 'brew':
      return 'managing Homebrew packages';
    default:
      return null;
  }
}

/// The leading `# …` comment of a code payload, when the caller wrote one —
/// that comment is the human step label.
String? _leadingComment(String code) {
  for (final line in code.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) continue;
    if (trimmed.startsWith('#')) {
      final text = _oneline(trimmed.substring(1));
      return text.isEmpty ? null : _clip(text, keepTail: false);
    }
    return null;
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
