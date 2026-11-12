import '../models/agent_thread.dart';
import '../models/gateway_activity.dart';
import '../models/gateway_insight.dart';
import '../services/thread_wire.dart';
import 'message_content.dart';

/// One activity row in the chat: a tool call or a block of reasoning.
///
/// [id] names the step rather than the slot it occupies, so the list can key
/// its row by it while other rows are added around it.
class ChatActivityStep {
  const ChatActivityStep.tool({
    required this.id,
    required GatewayToolActivity this.activity,
    this.storedRow,
  }) : reasoning = null,
       running = false;

  const ChatActivityStep.reasoning({
    required this.id,
    required String this.reasoning,
    this.running = false,
  }) : activity = null,
       storedRow = null;

  final String id;

  /// Set for a tool row.
  final GatewayToolActivity? activity;

  /// The full reasoning text, set for a reasoning row.
  final String? reasoning;

  /// The stored tool-result row this step was matched to, if the server has
  /// one. This is the map already held in the message list, not a copy: the
  /// detail sheet reads the output from it when it opens.
  final Map<String, dynamic>? storedRow;

  /// A reasoning row whose message has not produced any text yet.
  final bool running;

  bool get isReasoning => reasoning != null;

  bool get isRunning => isReasoning ? running : !activity!.isTerminal;

  bool get isFailed => activity?.isFailed ?? false;

  /// The reasoning row's label, or `null` when the text has no usable first
  /// line and the row should read as the generic "Thinking".
  String? get reasoningHeadline =>
      reasoning == null ? null : reasoningHeadlineOf(reasoning!);
}

/// A run of successful calls to the same tool, shown as one row in an
/// unfolded finished turn.
class ChatActivityGroupItem {
  const ChatActivityGroupItem({required this.id, required this.steps});

  final String id;
  final List<ChatActivityStep> steps;

  String get toolName => steps.first.activity!.name;

  List<GatewayToolActivity> get activities => [
    for (final step in steps) step.activity!,
  ];
}

/// The "Worked for…" line that stands in for a finished turn's steps.
class ChatTurnFold {
  const ChatTurnFold({
    required this.id,
    required this.unfolded,
    required this.stepCount,
    this.duration,
    this.failureCount = 0,
    this.aliases = const [],
  });

  /// The turn id the user's fold choice is remembered under: the stored id of
  /// the turn's user message, or the first tool call's identity until the
  /// server has stored the turn.
  final String id;

  /// Earlier ids of this same turn (its first tool call). A choice made under
  /// one of them is carried over to [id].
  final List<String> aliases;

  final bool unfolded;

  /// How long the turn worked, or `null` when either end is unknown and the
  /// line should state [stepCount] instead.
  final Duration? duration;

  /// Tool calls and reasoning blocks in the turn. Interim messages are not
  /// counted.
  final int stepCount;

  final int failureCount;

  bool get hasFailure => failureCount > 0;
}

/// The card a parent turn leaves when it starts threads: one row per thread,
/// each showing that thread's current state.
class ChatThreadsStartedItem {
  const ChatThreadsStartedItem({required this.id, required this.threads});

  final String id;
  final List<AgentThread> threads;
}

/// A finished thread's result, shown instead of the raw task-source text of
/// the parent turn that delivered it.
class ChatThreadReportItem {
  const ChatThreadReportItem({required this.id, required this.report});

  final String id;
  final ThreadReportAnnotation report;
}

/// An update or a question a running thread sent to the parent chat.
class ChatThreadMessageItem {
  const ChatThreadMessageItem({
    required this.id,
    required this.message,
    this.stored = true,
  });

  final String id;
  final ThreadMessageAnnotation message;

  /// False for a message delivered live that the stored history does not
  /// show yet.
  final bool stored;
}

/// The thread card a stored user row stands for, or `null` for a message a
/// person wrote.
///
/// The gateway's annotation decides (`display_kind`, `display_metadata`). A
/// row without one is matched on the gateway's own header at the very start
/// of its text, so a person's message that quotes a report is left alone.
Object? threadCardForUserRow(Map<String, dynamic> row, String text, int index) {
  final rowId = _rowId(row) ?? 'index:$index';
  final kind = row['display_kind'];
  final metadata = row['display_metadata'];
  if (kind == null || kind == '' || kind == ThreadDisplayKind.message) {
    final message =
        (kind == ThreadDisplayKind.message
            ? ThreadMessageAnnotation.parse(metadata)
            : null) ??
        ThreadMessageAnnotation.fromScaffold(text, rowId: rowId);
    if (message != null) {
      return ChatThreadMessageItem(
        id: 'thread-message:$rowId',
        message: message,
      );
    }
  }
  final report = ThreadReportAnnotation.classify(
    content: text,
    displayKind: kind,
    displayMetadata: metadata,
  );
  if (report != null) {
    return ChatThreadReportItem(id: 'thread-report:$rowId', report: report);
  }
  return null;
}

bool _sameThreadMessage(ThreadMessageAnnotation a, ThreadMessageAnnotation b) {
  if (a.messageId == b.messageId) return true;
  if (a.subagentId != b.subagentId || a.kind != b.kind) return false;
  return a.isQuestion
      ? a.questionId != null && a.questionId == b.questionId
      : a.text.trim() == b.text.trim();
}

/// The first non-empty line of [reasoning] with markdown markers removed, or
/// `null` when that line has no letters or digits.
String? reasoningHeadlineOf(String reasoning) {
  for (final rawLine in reasoning.split('\n')) {
    var line = rawLine.trim();
    if (line.isEmpty) continue;
    line = line
        // Heading, quote and list markers at the start of the line.
        .replaceFirst(RegExp(r'^(?:#{1,6}\s+|>+\s*|[-*+]\s+|\d+[.)]\s+)+'), '')
        .replaceAll(RegExp(r'\*+|`+|~~'), '')
        // Underscores only where they mark emphasis, so snake_case survives.
        .replaceAll(
          RegExp(r'(?<![\p{L}\p{N}])_+|_+(?![\p{L}\p{N}])', unicode: true),
          '',
        )
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (!RegExp(r'[\p{L}\p{N}]', unicode: true).hasMatch(line)) return null;
    const maxLength = 160;
    return line.length <= maxLength
        ? line
        : '${line.substring(0, maxLength - 1)}…';
  }
  return null;
}

/// Groups runs of successful calls to the same tool (D5).
///
/// [entries] is one finished turn's steps in order: [ChatActivityStep]s and
/// message maps. Two or more consecutive completed tool steps with the same
/// tool name become one [ChatActivityGroupItem]. A failed step, a reasoning
/// row or a message ends the run and is passed through unchanged.
List<dynamic> groupActivitySteps(List<dynamic> entries) {
  final grouped = <dynamic>[];
  final run = <ChatActivityStep>[];

  void flush() {
    if (run.isEmpty) return;
    if (run.length == 1) {
      grouped.add(run.single);
    } else {
      grouped.add(
        ChatActivityGroupItem(
          id: '${run.first.id}:group',
          steps: List.unmodifiable(run),
        ),
      );
    }
    run.clear();
  }

  for (final entry in entries) {
    final activity = entry is ChatActivityStep ? entry.activity : null;
    final groupable =
        activity != null &&
        activity.phase == GatewayToolActivityPhase.completed;
    if (!groupable) {
      flush();
      grouped.add(entry);
      continue;
    }
    if (run.isNotEmpty &&
        run.first.activity!.name.toLowerCase() != activity.name.toLowerCase()) {
      flush();
    }
    run.add(entry as ChatActivityStep);
  }
  flush();
  return grouped;
}

/// How long a turn worked (D4): from the user message to the final answer,
/// using the stored `timestamp` of each when the server has one and the time
/// this device observed (`_turn_started_at`, `_turn_ended_at`) otherwise.
/// `null` when either end is unknown or they are out of order.
Duration? turnWorkDuration(
  Map<String, dynamic>? userMessage,
  Map<String, dynamic>? finalAnswer,
) {
  DateTime? at(Map<String, dynamic>? message, String observedKey) {
    if (message == null) return null;
    final stored = GatewayToolActivity.storedResultTime(message['timestamp']);
    if (stored != null) return stored;
    final observed = message[observedKey];
    return observed is DateTime ? observed.toUtc() : null;
  }

  final start = at(userMessage, '_turn_started_at');
  final end = at(finalAnswer, '_turn_ended_at');
  if (start == null || end == null || end.isBefore(start)) return null;
  return end.difference(start);
}

/// When a turn began: its user message's stored time, or the time this
/// device sent it.
DateTime? _turnStart(Map<String, dynamic>? userMessage) {
  if (userMessage == null) return null;
  final stored = GatewayToolActivity.storedResultTime(userMessage['timestamp']);
  if (stored != null) return stored;
  final observed = userMessage['_turn_started_at'];
  return observed is DateTime ? observed.toUtc() : null;
}

class _Turn {
  _Turn(this.index, {this.user, this.rawUser});

  /// Position of the turn's first message, the fallback for its id.
  final int index;

  /// What opens the turn as displayed (a user bubble, or the thread card a
  /// gateway-written row stands for), and the stored message it came from.
  final Object? user;
  final Map<String, dynamic>? rawUser;

  /// [ChatActivityStep]s and assistant message maps, in the order they
  /// happened.
  final List<dynamic> entries = [];

  bool get isEmpty => user == null && entries.isEmpty;
}

String? _rowId(Map<String, dynamic> message) {
  final id = message['id'] ?? message['message_id'];
  if (id is num) return 'message:$id';
  if (id is String && id.isNotEmpty) return 'message:$id';
  return null;
}

/// Project a raw Hermes message list into the flat list the chat screen
/// renders.
///
/// Messages are first collected into turns: a user message, the ordered steps
/// the agent took (tool calls, reasoning, interim messages) and the final
/// answer. Each turn is then flattened (D1):
///
/// - a finished turn that used tools or reasoning: user bubble, a
///   [ChatTurnFold], its steps only when the user unfolded it (with runs of
///   one tool grouped into a [ChatActivityGroupItem]), then the final answer;
/// - a running turn, or one that ended without a final answer: user bubble,
///   then every step as its own [ChatActivityStep] or bubble;
/// - a plain reply: user bubble and answer.
///
/// Bubbles are `Map<String, dynamic>` carrying `_display_content` (tool-result
/// blocks stripped) and, for assistant replies, `_retry_prompt`. A
/// `GatewaySubagentActivity` list and [GatewayNotice]s are appended last.
///
/// A user row the gateway wrote for a thread becomes a [ChatThreadReportItem]
/// or a [ChatThreadMessageItem] instead of a bubble. Each of [threads] is
/// listed in one [ChatThreadsStartedItem], placed after the turn that was
/// running when the thread started. [liveThreadMessages] not yet in the
/// stored history are appended as cards.
///
/// Stored tool-result messages consume [toolActivities] in order. An activity
/// left over (streamed, not yet stored) is placed after the message it is
/// anchored to (D2), or at the end when it has no anchor. The caller's list
/// is never mutated.
///
/// [turnActive] says the last turn is still running. [foldChoice] returns the
/// user's choice for a turn id: `true` unfolded, `false` folded, `null` for
/// the default (folded).
List<dynamic> buildChatDisplayItems({
  required List<Map<String, dynamic>> messages,
  List<GatewayToolActivity> toolActivities = const [],
  List<GatewaySubagentActivity> subagentActivities = const [],
  List<GatewayNotice> notices = const [],
  List<AgentThread> threads = const [],
  List<ThreadMessageAnnotation> liveThreadMessages = const [],
  bool turnActive = false,
  bool? Function(String turnId)? foldChoice,
}) {
  // One activity per stored tool-result row, in order; the rest are live.
  final storedRowCount = messages.where(isToolResultMessage).length;
  final storedCount = storedRowCount < toolActivities.length
      ? storedRowCount
      : toolActivities.length;
  final live = toolActivities.sublist(storedCount);
  var storedIndex = 0;
  var liveIndex = 0;

  final turns = <_Turn>[];
  var current = _Turn(0);
  String? lastUserPrompt;

  ChatActivityStep toolStep(
    GatewayToolActivity activity, [
    Map<String, dynamic>? storedRow,
  ]) => ChatActivityStep.tool(
    id: activity.identity,
    activity: activity,
    storedRow: storedRow,
  );

  // Unstored activities anchored at or before message [index] belong here.
  // Start order is kept: one without an anchor holds back those after it,
  // and they all land at the end.
  void placeLiveUpTo(int index) {
    while (liveIndex < live.length) {
      final anchor = live[liveIndex].anchorMessageIndex;
      if (anchor == null || anchor > index) break;
      current.entries.add(toolStep(live[liveIndex++]));
    }
  }

  for (final (index, msg) in messages.indexed) {
    final rawRole = (msg['role'] as String?) ?? 'assistant';
    final role = rawRole == 'agent' ? 'assistant' : rawRole;
    if (isToolResultMessage(msg)) {
      if (storedIndex < storedCount) {
        current.entries.add(toolStep(toolActivities[storedIndex++], msg));
      }
      placeLiveUpTo(index);
      continue;
    }
    if (role == 'user' || role == 'assistant') {
      final content = stripToolResultText(messageContentToText(msg['content']));
      final reasoning = msg['_gateway_reasoning']?.toString() ?? '';
      final hasReasoning = role == 'assistant' && reasoning.trim().isNotEmpty;

      if (role == 'user' && content.isNotEmpty) {
        if (!current.isEmpty) turns.add(current);
        final card = threadCardForUserRow(msg, content, index);
        // A gateway-written turn has no prompt of the user's to retry.
        lastUserPrompt = card == null ? content : null;
        current = _Turn(
          index,
          rawUser: msg,
          user: card ?? {...msg, 'role': role, '_display_content': content},
        );
      } else if (role == 'assistant') {
        if (hasReasoning) {
          current.entries.add(
            ChatActivityStep.reasoning(
              id: 'reasoning:${_rowId(msg) ?? index}',
              reasoning: reasoning,
              running:
                  content.isEmpty && msg['_gateway_pending_response'] == true,
            ),
          );
        }
        if (content.isNotEmpty) {
          current.entries.add({
            ...msg,
            'role': role,
            '_display_content': content,
            '_retry_prompt': ?lastUserPrompt,
          });
        }
      }
    }
    placeLiveUpTo(index);
  }
  // Activities with no anchor (or one past the end) trail the last turn.
  while (liveIndex < live.length) {
    current.entries.add(toolStep(live[liveIndex++]));
  }
  if (!current.isEmpty) turns.add(current);

  // Each thread belongs to the turn that was running when it started: the
  // last turn that began at or before the thread did.
  final startedByTurn = <int, List<AgentThread>>{};
  if (threads.isNotEmpty) {
    final turnStarts = [for (final turn in turns) _turnStart(turn.rawUser)];
    for (final thread in threads) {
      final spawned = thread.spawnedAt;
      var owner = turns.length - 1;
      if (spawned != null) {
        final limit = spawned.add(const Duration(seconds: 2));
        for (var index = turns.length - 1; index >= 0; index--) {
          final start = turnStarts[index];
          if (start != null && !start.isAfter(limit)) {
            owner = index;
            break;
          }
        }
      }
      startedByTurn.putIfAbsent(owner, () => []).add(thread);
    }
  }
  ChatThreadsStartedItem startedCard(List<AgentThread> started) =>
      ChatThreadsStartedItem(
        id: 'threads-started:${started.first.id}',
        threads: List.unmodifiable(started),
      );

  final displayItems = <dynamic>[];
  for (final (turnIndex, turn) in turns.indexed) {
    final running = turnActive && turnIndex == turns.length - 1;
    if (turn.user != null) displayItems.add(turn.user);
    final started = startedByTurn[turnIndex];

    final last = turn.entries.isEmpty ? null : turn.entries.last;
    final finalAnswer =
        !running &&
            last is Map<String, dynamic> &&
            last['_gateway_interim'] != true
        ? last
        : null;
    final steps = finalAnswer == null
        ? turn.entries
        : turn.entries.sublist(0, turn.entries.length - 1);
    final activitySteps = steps.whereType<ChatActivityStep>().toList();

    if (finalAnswer == null || activitySteps.isEmpty) {
      // Running, interrupted, or a reply that needed no tools: nothing folds.
      displayItems.addAll(turn.entries);
      if (started != null) displayItems.add(startedCard(started));
      continue;
    }

    final toolSteps = activitySteps.where((step) => !step.isReasoning);
    final firstToolStep = toolSteps.isEmpty ? null : toolSteps.first;
    final firstTool = firstToolStep?.activity;
    final storedId = turn.rawUser == null ? null : _rowId(turn.rawUser!);
    final firstRowId = firstToolStep?.storedRow == null
        ? null
        : _rowId(firstToolStep!.storedRow!);
    final turnId =
        storedId ?? firstRowId ?? firstTool?.identity ?? 'turn:${turn.index}';
    final firstToolId = firstTool?.toolId;
    // Earlier ids of this turn: a choice made under one of them still
    // applies until the caller has carried it over to [turnId].
    final aliases = <String>[
      if ((storedId ?? firstRowId) != null && firstTool != null) ...{
        if (firstToolId != null && firstToolId.isNotEmpty) 'tool:$firstToolId',
        firstTool.identity,
      },
    ];
    var choice = foldChoice?.call(turnId);
    for (final alias in aliases) {
      choice ??= foldChoice?.call(alias);
    }
    final unfolded = choice ?? false;

    displayItems.add(
      ChatTurnFold(
        id: turnId,
        aliases: aliases,
        unfolded: unfolded,
        duration: turnWorkDuration(turn.rawUser, finalAnswer),
        stepCount: activitySteps.length,
        failureCount: activitySteps.where((step) => step.isFailed).length,
      ),
    );
    if (unfolded) displayItems.addAll(groupActivitySteps(steps));
    displayItems.add(finalAnswer);
    if (started != null) displayItems.add(startedCard(started));
  }
  // Threads with no turn to belong to (an empty chat) still get their card.
  if (turns.isEmpty && threads.isNotEmpty) {
    displayItems.add(startedCard(threads));
  }

  if (liveThreadMessages.isNotEmpty) {
    final stored = [
      for (final item in displayItems.whereType<ChatThreadMessageItem>())
        item.message,
    ];
    for (final message in liveThreadMessages) {
      if (stored.any((other) => _sameThreadMessage(other, message))) continue;
      displayItems.add(
        ChatThreadMessageItem(
          id: 'thread-message:live:${message.messageId}',
          message: message,
          stored: false,
        ),
      );
    }
  }

  if (subagentActivities.isNotEmpty) {
    displayItems.add(List<GatewaySubagentActivity>.from(subagentActivities));
  }
  displayItems.addAll(notices);

  return displayItems;
}
