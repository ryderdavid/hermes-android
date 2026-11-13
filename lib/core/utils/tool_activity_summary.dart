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

import 'dart:convert';

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

/// Whether an argument named [key] may hold a secret and must not be shown.
bool isSensitiveToolArgKey(String key) => _isSensitiveKey(key);

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

/// Maps a shell command's first line to a plain-language sentence about its
/// *purpose* — "installing speedtest-cli", "checking if X is installed",
/// "running a speed test" — never the raw command. Compound commands
/// (`a && b`) are split and each segment is summarized. Returns null only when
/// nothing parseable remains (the caller falls back to a generic phrase).
String? commandSentence(String command) {
  final firstLine = command
      .split('\n')
      .firstWhere((line) => line.trim().isNotEmpty, orElse: () => '');
  final cleaned = _stripShellNoise(firstLine);
  final segments = _splitCompound(cleaned);
  final phrases = <String>[
    for (final segment in segments) ?_segmentSentence(segment),
  ];
  if (phrases.isEmpty) return null;
  return _clip(phrases.join(', '), keepTail: false);
}

/// Drops redirects, trailing background `&`, and `sudo` so the real command
/// shows through.
String _stripShellNoise(String line) {
  var cleaned = line;
  cleaned = cleaned.replaceAll(RegExp(r'\s*2?>&?\d*(/[^\s]+)?'), ' ');
  cleaned = cleaned.replaceAll(RegExp(r'\s*>\s*/[^\s]+'), ' ');
  cleaned = cleaned.replaceAll(RegExp(r'\s*>\s*[^\s]+'), ' ');
  if (cleaned.trim().endsWith('&')) {
    cleaned = cleaned.trim().substring(0, cleaned.trim().length - 1);
  }
  final parts = cleaned.trim().split(RegExp(r'\s+'));
  if (parts.isNotEmpty && parts[0] == 'sudo' && parts.length > 1) {
    return parts.sublist(1).join(' ');
  }
  return cleaned;
}

List<String> _splitCompound(String line) {
  final segments = <String>[];
  final current = StringBuffer();
  var i = 0;
  var quote = '';
  while (i < line.length) {
    final ch = line[i];
    if (quote.isNotEmpty) {
      current.write(ch);
      if (ch == quote) quote = '';
    } else if (ch == '"' || ch == "'") {
      quote = ch;
      current.write(ch);
    } else if (ch == '&' && i + 1 < line.length && line[i + 1] == '&') {
      segments.add(current.toString());
      current.clear();
      i += 2;
      continue;
    } else if (ch == '|' && (i + 1 >= line.length || line[i + 1] != '|')) {
      segments.add(current.toString());
      current.clear();
    } else if (ch == ';') {
      segments.add(current.toString());
      current.clear();
    } else {
      current.write(ch);
    }
    i++;
  }
  segments.add(current.toString());
  return [
    for (final s in segments)
      if (s.trim().isNotEmpty) s.trim(),
  ];
}

/// Well-known binaries whose purpose beats their name.
const Map<String, String> _knownToolPurposes = {
  'speedtest-cli': 'running a speed test',
  'speedtest': 'running a speed test',
  'fast': 'running a speed test',
  'pytest': 'running the Python tests',
  'nmap': 'scanning the network',
  'htop': 'watching system processes',
  'top': 'watching system processes',
  'ffmpeg': 'processing media',
  'docker': 'managing containers',
  'kubectl': 'managing Kubernetes',
  'terraform': 'managing infrastructure',
  'ansible': 'running automation',
  'vim': 'editing a file',
  'nano': 'editing a file',
  'code': 'opening the editor',
};

String? _segmentSentence(String segment) {
  var parts = segment.trim().split(RegExp(r'\s+'));
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
  final args = parts.sublist(1);
  final positional = [
    for (final a in args)
      if (!a.startsWith('-') && !a.contains('=')) a,
  ];
  final firstArg = positional.isNotEmpty ? positional.first : '';

  final known = _knownToolPurposes[bin];
  if (known != null) return known;

  switch (bin) {
    case 'which':
    case 'command':
    case 'type':
      return firstArg.isNotEmpty
          ? 'checking if $firstArg is installed'
          : 'looking up a command';
    case 'pip':
    case 'pip3':
      if (args.contains('install') || args.contains('i')) {
        final r = args.indexOf('-r');
        if (r != -1 && r + 1 < args.length) {
          return 'installing dependencies from ${args[r + 1]}';
        }
        final pkg = positional
            .where((a) => a != 'install' && a != 'i')
            .firstOrNull;
        return pkg != null ? 'installing $pkg' : 'installing Python packages';
      }
      if (args.contains('uninstall')) {
        return 'uninstalling ${positional.isNotEmpty ? positional.first : 'a package'}';
      }
      if (args.contains('list') || args.contains('show')) {
        return 'listing Python packages';
      }
      return 'managing Python packages';
    case 'apt':
    case 'apt-get':
      // Skip the subcommand itself when picking the package name.
      final aptPositional = [
        for (final a in args.skip(1))
          if (!a.startsWith('-') && !a.contains('=')) a,
      ];
      if (args.contains('install')) {
        return 'installing ${aptPositional.isNotEmpty ? aptPositional.first : 'a package'}';
      }
      if (args.contains('update')) return 'updating package lists';
      if (args.contains('upgrade')) return 'upgrading packages';
      if (args.contains('remove') || args.contains('purge')) {
        return 'removing ${aptPositional.isNotEmpty ? aptPositional.first : 'a package'}';
      }
      return 'managing system packages';
    case 'brew':
      final brewPositional = [
        for (final a in args.skip(1))
          if (!a.startsWith('-') && !a.contains('=')) a,
      ];
      if (args.contains('install')) {
        return 'installing ${brewPositional.isNotEmpty ? brewPositional.first : 'a package'}';
      }
      if (args.contains('uninstall')) return 'uninstalling a package';
      if (args.contains('list')) return 'listing installed packages';
      if (args.contains('update') || args.contains('upgrade')) {
        return 'updating Homebrew packages';
      }
      return 'managing Homebrew packages';
    case 'npm':
      if (args.contains('install') ||
          args.contains('i') ||
          args.contains('add')) {
        final pkg = positional
            .where(
              (a) => !{'install', 'i', 'add', '-g', '--global'}.contains(a),
            )
            .firstOrNull;
        return pkg != null ? 'installing $pkg' : 'installing npm dependencies';
      }
      if (args.contains('run')) {
        return 'running npm script ${positional.isNotEmpty ? positional.first : ''}'
            .trim();
      }
      if (args.contains('test')) return 'running npm tests';
      if (args.contains('uninstall') || args.contains('remove')) {
        return 'removing an npm package';
      }
      return 'managing npm packages';
    case 'npx':
      return firstArg.isNotEmpty ? 'running $firstArg' : 'running a package';
    case 'flutter':
      if (args.firstOrNull == 'test') return 'running the test suite';
      if (args.firstOrNull == 'analyze') return 'checking the code for issues';
      if (args.firstOrNull == 'build') return 'building the app';
      if (args.firstOrNull == 'pub') return 'updating package dependencies';
      if (args.firstOrNull == 'run') return 'launching the app';
      if (args.firstOrNull == 'doctor') return 'checking the Flutter setup';
      if (args.firstOrNull == 'clean') return 'cleaning build artifacts';
      return 'working with Flutter';
    case 'dart':
      if (args.firstOrNull == 'format') return 'formatting the code';
      if (args.firstOrNull == 'test') return 'running the test suite';
      return 'running Dart code';
    case 'git':
      final sub = args.firstOrNull ?? '';
      if (sub == 'commit') return 'committing changes';
      if (sub == 'push') return 'pushing to the remote';
      if (sub == 'pull' || sub == 'fetch') return 'fetching from the remote';
      if (sub == 'rebase' || sub == 'merge') return 'merging changes';
      if (sub == 'add' || sub == 'stage') return 'staging changes';
      if (sub == 'status') return 'checking repo status';
      if (sub == 'diff') return 'reviewing changes';
      if (sub == 'log') return 'reviewing commit history';
      if (sub == 'show') return 'inspecting a commit';
      if (sub == 'branch') return 'managing branches';
      if (sub == 'checkout' || sub == 'switch') return 'switching branches';
      if (sub == 'tag') return 'tagging a release';
      if (sub == 'clone') {
        return 'cloning ${firstArg.isNotEmpty ? firstArg : 'a repo'}';
      }
      if (sub == 'stash') return 'stashing changes';
      return 'working with git';
    case 'bd':
      final sub = args.firstOrNull ?? '';
      if (sub == 'create') return 'filing an issue';
      if (sub == 'close') return 'closing an issue';
      if (sub == 'ready') return 'listing ready work';
      if (sub == 'list') return 'listing issues';
      if (sub == 'update') return 'updating an issue';
      if (sub == 'show') return 'reading an issue';
      return 'updating the issue tracker';
    case 'gh':
      final sub = args.firstOrNull ?? '';
      if (sub == 'release') {
        return args.contains('create')
            ? 'publishing a release'
            : args.contains('download')
            ? 'downloading release assets'
            : 'managing releases';
      }
      if (sub == 'pr') return 'working on a pull request';
      if (sub == 'issue') return 'working on an issue';
      if (sub == 'auth') return 'checking GitHub auth';
      if (sub == 'repo') return 'managing the repo';
      return 'working with GitHub';
    case 'tailscale':
      final sub = args.firstOrNull ?? '';
      if (sub == 'file') return 'sending a file over Taildrop';
      if (sub == 'status') return 'checking the Tailnet';
      if (sub == 'up' || sub == 'down') return 'toggling the VPN';
      return 'managing the Tailnet';
    case 'adb':
      final sub = args.firstOrNull ?? '';
      if (sub == 'connect') return 'connecting to the phone over adb';
      if (sub == 'shell') return 'running a command on the phone';
      if (sub == 'install') return 'installing an APK on the phone';
      if (sub == 'logcat') return 'reading phone logs';
      if (sub == 'devices') return 'listing connected devices';
      return 'talking to the Android device';
    case 'python3':
    case 'python':
      if (firstArg.endsWith('.py')) return 'running $firstArg';
      if (args.contains('-m')) {
        final mod =
            args[args.indexOf('-m') + 1 < args.length
                ? args.indexOf('-m') + 1
                : 0];
        return 'running Python module $mod';
      }
      return 'running a Python script';
    case 'bash':
    case 'sh':
    case 'zsh':
      return firstArg.isNotEmpty
          ? 'running $firstArg'
          : 'running a shell script';
    case 'curl':
    case 'wget':
      final url = args.firstWhere(
        (a) => a.startsWith('http'),
        orElse: () => '',
      );
      if (url.isNotEmpty) return 'downloading $url';
      return 'making an HTTP request';
    case 'ssh':
      return firstArg.isNotEmpty
          ? 'connecting to $firstArg'
          : 'connecting over SSH';
    case 'scp':
      return 'copying files over SSH';
    case 'ls':
    case 'll':
      return firstArg.isNotEmpty ? 'listing $firstArg' : 'listing files';
    case 'cd':
      return firstArg.isNotEmpty
          ? 'changing to $firstArg'
          : 'changing directory';
    case 'cat':
      return firstArg.isNotEmpty ? 'reading $firstArg' : 'reading a file';
    case 'head':
    case 'tail':
      return firstArg.isNotEmpty ? 'previewing $firstArg' : 'previewing a file';
    case 'grep':
    case 'rg':
      final pattern =
          _firstQuoted(args) ??
          (args.contains('-e')
              ? args[args.indexOf('-e') + 1 < args.length
                    ? args.indexOf('-e') + 1
                    : 0]
              : '');
      final target = positional.isNotEmpty ? positional.last : '';
      if (pattern.isNotEmpty) {
        return target.isNotEmpty
            ? 'searching $target for "$pattern"'
            : 'searching for "$pattern"';
      }
      return 'searching files';
    case 'find':
      final nameIdx = args.indexOf('-name');
      if (nameIdx != -1 && nameIdx + 1 < args.length) {
        return 'finding files matching ${args[nameIdx + 1]}';
      }
      return firstArg.isNotEmpty ? 'searching $firstArg' : 'finding files';
    case 'sed':
      return 'editing files in place';
    case 'cp':
      return positional.length >= 2
          ? 'copying ${positional[0]} to ${positional[1]}'
          : 'copying files';
    case 'mv':
      return positional.length >= 2
          ? 'moving ${positional[0]} to ${positional[1]}'
          : 'moving files';
    case 'rm':
      return firstArg.isNotEmpty ? 'deleting $firstArg' : 'deleting files';
    case 'chmod':
    case 'chown':
      return 'changing permissions on ${firstArg.isNotEmpty ? firstArg : 'files'}';
    case 'mkdir':
      return 'creating ${firstArg.isNotEmpty ? firstArg : 'a directory'}';
    case 'df':
      return 'checking disk space';
    case 'du':
      return 'measuring disk usage';
    case 'free':
      return 'checking memory usage';
    case 'ps':
      return 'listing processes';
    case 'kill':
    case 'pkill':
      return 'stopping ${firstArg.isNotEmpty ? firstArg : 'a process'}';
    case 'sleep':
      return 'waiting ${firstArg.isNotEmpty ? firstArg : ''} seconds'.trim();
    case 'tar':
      return 'working with an archive';
    case 'uname':
      return 'checking system info';
    case 'open':
      return 'opening ${firstArg.isNotEmpty ? firstArg : 'something'}';
    default:
      // Name the tool at least — better than "a shell command".
      return 'running `$bin`';
  }
}

String? _firstQuoted(List<String> args) {
  for (final a in args) {
    final trimmed = a.trim();
    if (trimmed.length >= 2 &&
        ((trimmed.startsWith('"') && trimmed.endsWith('"')) ||
            (trimmed.startsWith("'") && trimmed.endsWith("'")))) {
      return trimmed.substring(1, trimmed.length - 1);
    }
  }
  return null;
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

/// Maps tool-call id → parsed arguments for every message in [messages] that
/// carries `tool_calls`. Stored tool-result rows reference their call by
/// `tool_call_id` but do not repeat the args (the REST history ships the args
/// only on the assistant message), so a stored row's summary is phrased from
/// the matching call joined here.
Map<String, Map<String, dynamic>> toolCallArgsById(
  List<Map<String, dynamic>> messages,
) {
  final result = <String, Map<String, dynamic>>{};
  for (final message in messages) {
    final calls = message['tool_calls'];
    if (calls is! List) continue;
    for (final call in calls) {
      if (call is! Map) continue;
      final id = (call['id'] as String?) ?? (call['call_id'] as String?) ?? '';
      final function = call['function'];
      if (id.isEmpty || function is! Map) continue;
      final args = _parseToolCallArguments(function['arguments']);
      if (args != null) result[id] = args;
    }
  }
  return result;
}

Map<String, dynamic>? _parseToolCallArguments(dynamic raw) {
  if (raw is Map) return raw.cast<String, dynamic>();
  if (raw is String && raw.trim().isNotEmpty) {
    try {
      final parsed = jsonDecode(raw);
      if (parsed is Map) return parsed.cast<String, dynamic>();
    } catch (_) {
      // Malformed arguments stay absent; the row falls back to the preview.
    }
  }
  return null;
}
