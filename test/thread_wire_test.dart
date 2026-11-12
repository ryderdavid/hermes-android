import 'package:flutter_test/flutter_test.dart';
import 'package:hermes_android/core/services/thread_wire.dart';

const _single = '''
[ASYNC DELEGATION COMPLETE — deleg_9f8e7d6c]
A background subagent you dispatched earlier has finished. You may have moved on since dispatching it; the full task source is below so you can act on the result or re-dispatch if things have changed.

Dispatched: 2026-11-11 10:15:00 (3m ago)
Original goal: Draft release notes
Context you provided: Leave the Office previews out.
Role: leaf   Model: sonnet
Status: completed   API calls: 9   Duration: 184.2s
--- RESULT ---
Drafted docs/releases/v3.2.0-you.1.md: 9 user-facing changes.
Two items need a screenshot before publishing.
Full live transcript (complete tool/assistant trace): /tmp/live/task-0.log''';

const _failedSingle = '''
[ASYNC DELEGATION COMPLETE — deleg_1]
A background subagent you dispatched earlier has finished.

Original goal: Check CI matrix
Status: error   Duration: 12.0s
--- RESULT ---
The subagent did not complete successfully (status=error).
model not found''';

const _batch = '''
[ASYNC DELEGATION BATCH COMPLETE — deleg_batch]
A background fan-out unit you dispatched earlier — 2 subagent(s) — has finished; its consolidated results are below.

Dispatched: 2026-11-11 10:15:00 (5m ago)   Total duration: 240.0s

--- ✓ TASK 1/2: Audit dependency licences  (status=completed, api_calls=4, 120.5s) ---
41 of 48 runtime packages are MIT/BSD/Apache.

--- ✗ TASK 2/2: Check CI matrix  (status=failed, 60.0s) ---
(no summary — status=failed: gh not installed)''';

const _earlyFailure = '''
[ASYNC DELEGATION TASK FAILED — deleg_batch, task 2/3]
One subagent in a background fan-out you dispatched has failed while its siblings are still running.
Task: Check CI matrix
Status: error   Duration: 4.0s
Error: gh not installed''';

void main() {
  group('ThreadReportAnnotation.classify', () {
    test('annotated turn: the server annotation names the threads', () {
      final report = ThreadReportAnnotation.classify(
        content: _single.trim(),
        displayKind: 'async_delegation_complete',
        displayMetadata: {
          'display_text': 'Subagent Task Completed: Draft release notes',
          'delegation_id': 'deleg_9f8e7d6c',
          'task_count': 1,
          'completed_count': 1,
          'failed_count': 0,
          'duration_seconds': 184.2,
          'threads': [
            {
              'subagent_id': 'sa-0-1a2b3c4d',
              'task_index': 0,
              'goal': 'Draft release notes',
              'status': 'completed',
              'tool_count': 12,
              'duration_seconds': 184.2,
            },
          ],
        },
      )!;

      expect(report.delegationId, 'deleg_9f8e7d6c');
      final entry = report.entries.single;
      expect(entry.subagentId, 'sa-0-1a2b3c4d');
      expect(entry.goal, 'Draft release notes');
      expect(entry.status, 'completed');
      expect(entry.toolCount, 12);
      expect(entry.durationSeconds, 184.2);
      // The annotation carries no result text; it comes from the content,
      // without the transcript path meant for the model.
      expect(
        entry.summary,
        'Drafted docs/releases/v3.2.0-you.1.md: 9 user-facing changes.\n'
        'Two items need a screenshot before publishing.',
      );
    });

    test('annotation delivered as a JSON string', () {
      final report = ThreadReportAnnotation.classify(
        content: _single.trim(),
        displayKind: 'async_delegation_complete',
        displayMetadata:
            '{"delegation_id":"deleg_9f8e7d6c","threads":[{"subagent_id":"sa-1",'
            '"task_index":0,"goal":"Draft release notes","status":"completed",'
            '"tool_count":3,"duration_seconds":10}]}',
      )!;

      expect(report.entries.single.subagentId, 'sa-1');
      expect(report.entries.single.toolCount, 3);
    });

    test('legacy turn: classified by the gateway header alone', () {
      final report = ThreadReportAnnotation.classify(content: _single.trim())!;

      expect(report.delegationId, 'deleg_9f8e7d6c');
      final entry = report.entries.single;
      expect(entry.subagentId, isNull);
      expect(entry.goal, 'Draft release notes');
      expect(entry.status, 'completed');
      expect(entry.durationSeconds, 184.2);
      expect(entry.summary, startsWith('Drafted docs/releases'));
    });

    test('display_kind without metadata still uses the text', () {
      // The REST history returns display_kind but not display_metadata.
      final report = ThreadReportAnnotation.classify(
        content: _single.trim(),
        displayKind: 'async_delegation_complete',
      )!;

      expect(report.entries.single.goal, 'Draft release notes');
    });

    test('legacy failure', () {
      final entry = ThreadReportAnnotation.classify(
        content: _failedSingle.trim(),
      )!.entries.single;

      expect(entry.status, 'error');
      expect(ThreadOutcome.succeeded(entry.status), isFalse);
      expect(entry.summary, contains('model not found'));
    });

    test('batch: one entry per task, matched to the annotation by index', () {
      final report = ThreadReportAnnotation.classify(
        content: _batch.trim(),
        displayKind: 'async_delegation_complete',
        displayMetadata: {
          'delegation_id': 'deleg_batch',
          'threads': [
            {
              'subagent_id': 'sa-b',
              'task_index': 1,
              'goal': 'Check CI matrix',
              'status': 'failed',
              'tool_count': 2,
            },
            {
              'subagent_id': 'sa-a',
              'task_index': 0,
              'goal': 'Audit dependency licences',
              'status': 'completed',
              'tool_count': 7,
            },
          ],
        },
      )!;

      expect(report.entries.map((e) => e.subagentId), ['sa-b', 'sa-a']);
      expect(report.entries[0].summary, contains('gh not installed'));
      expect(report.entries[0].durationSeconds, 60.0);
      expect(report.entries[1].summary, startsWith('41 of 48'));
      expect(report.entries[1].durationSeconds, 120.5);
    });

    test('legacy batch', () {
      final report = ThreadReportAnnotation.classify(content: _batch.trim())!;

      expect(report.entries.map((e) => e.goal), [
        'Audit dependency licences',
        'Check CI matrix',
      ]);
      expect(report.entries.map((e) => e.status), ['completed', 'failed']);
    });

    test('early failure warning of a running batch', () {
      final report = ThreadReportAnnotation.classify(
        content: _earlyFailure.trim(),
      )!;

      expect(report.earlyFailure, isTrue);
      final entry = report.entries.single;
      expect(entry.taskIndex, 1);
      expect(entry.goal, 'Check CI matrix');
      expect(entry.status, 'error');
      expect(entry.summary, 'gh not installed');
    });

    test('annotated completion with no per-thread rows', () {
      final report = ThreadReportAnnotation.classify(
        content: 'The unit stalled.',
        displayKind: 'async_delegation_complete',
        displayMetadata: {
          'display_text': 'Subagent Task Failed: Check CI matrix',
          'delegation_id': 'deleg_x',
          'failed_count': 1,
        },
      )!;

      expect(report.entries.single.goal, contains('Check CI matrix'));
      expect(report.entries.single.status, 'failed');
      expect(report.entries.single.subagentId, isNull);
    });

    test('human text that mentions a report is left alone', () {
      expect(
        ThreadReportAnnotation.classify(
          content:
              'Why did I get this?\n\n[ASYNC DELEGATION COMPLETE — deleg_1]\n'
              'Status: completed\n--- RESULT ---\nDone.',
        ),
        isNull,
      );
      expect(
        ThreadReportAnnotation.classify(content: 'Plan the 3.2 release.'),
        isNull,
      );
    });

    test('another display kind is never a report', () {
      expect(
        ThreadReportAnnotation.classify(
          content: _single.trim(),
          displayKind: 'async_delegation_message',
        ),
        isNull,
      );
    });
  });

  group('ThreadMessageAnnotation', () {
    test('parses an update', () {
      final message = ThreadMessageAnnotation.parse({
        'type': 'async_delegation_message',
        'display_text': 'Thread Update: Check the licences',
        'message_id': 'dmsg_4c5d6e7f80',
        'kind': 'update',
        'text': '2 of 5 jobs fail on Android API 35',
        'subagent_id': 'sa-0-1a2b3c4d',
        'delegation_id': 'deleg_9f8e7d6c',
        'goal': 'Check the licences',
        'sent_at': 1767000050.0,
        'merged_count': 3,
      })!;

      expect(message.kind, ThreadMessageKind.update);
      expect(message.messageId, 'dmsg_4c5d6e7f80');
      expect(message.text, '2 of 5 jobs fail on Android API 35');
      expect(message.goal, 'Check the licences');
      expect(message.mergedCount, 3);
      expect(message.questionId, isNull);
    });

    test('parses a question with its wait limit', () {
      final message = ThreadMessageAnnotation.parse({
        'type': 'async_delegation_message',
        'message_id': 'dmsg_91',
        'kind': 'question',
        'text': 'Drop the two AGPL packages?',
        'subagent_id': 'sa-0',
        'goal': 'Check the licences',
        'sent_at': 1767000100.0,
        'question_id': 'q_0a1b2c3d4e',
        'options': ['Drop', 'Flag for legal'],
        'timeout_seconds': 900.0,
      })!;

      expect(message.isQuestion, isTrue);
      expect(message.questionId, 'q_0a1b2c3d4e');
      expect(message.options, ['Drop', 'Flag for legal']);
      expect(
        message.expiresAt,
        DateTime.fromMillisecondsSinceEpoch(1767001000000, isUtc: true),
      );
    });

    test('rejects another annotation type and incomplete payloads', () {
      expect(
        ThreadMessageAnnotation.parse({
          'type': 'something_else',
          'kind': 'update',
          'subagent_id': 'sa-0',
        }),
        isNull,
      );
      expect(ThreadMessageAnnotation.parse({'kind': 'update'}), isNull);
      expect(ThreadMessageAnnotation.parse(null), isNull);
    });

    test('rebuilds an update from the scaffold text', () {
      final message = ThreadMessageAnnotation.fromScaffold('''
[THREAD UPDATE — sa-0-1a2b3c4d]
A background thread you started sent an interim update. It is still running; its final result arrives later as its own message. Tell the user briefly if this matters to them. Do not reply to the thread.
Thread task: Check CI matrix
(3 updates merged into this one)
--- UPDATE ---
2 of 5 jobs fail on Android API 35.

Still checking the other three.''', rowId: 'message:41')!;

      expect(message.kind, ThreadMessageKind.update);
      expect(message.subagentId, 'sa-0-1a2b3c4d');
      expect(message.goal, 'Check CI matrix');
      expect(
        message.text,
        '2 of 5 jobs fail on Android API 35.\n\nStill checking the other three.',
      );
      expect(message.messageId, 'row:message:41');
    });

    test('rebuilds a question, its id and options from the scaffold', () {
      final message = ThreadMessageAnnotation.fromScaffold('''
[THREAD QUESTION — sa-0-1a2b3c4d, question q_0a1b2c3d4e]
A background thread you started is paused, waiting for an answer to the question below.
Thread task: Audit dependency licences
--- QUESTION ---
Drop the two AGPL packages?
Options: Drop | Flag for legal''')!;

      expect(message.isQuestion, isTrue);
      expect(message.subagentId, 'sa-0-1a2b3c4d');
      expect(message.questionId, 'q_0a1b2c3d4e');
      expect(message.goal, 'Audit dependency licences');
      expect(message.text, 'Drop the two AGPL packages?');
      expect(message.options, ['Drop', 'Flag for legal']);
    });

    test('text that only mentions a thread update is not one', () {
      expect(
        ThreadMessageAnnotation.fromScaffold(
          'What does "[THREAD UPDATE — sa-0]" mean?',
        ),
        isNull,
      );
    });
  });

  group('ThreadTailLine', () {
    const tail = '''
=== Hermes subagent live transcript ===
delegation: deleg_1   task: 0
goal: Audit dependency licences
========================================
14:32:01 user     | kickoff: Audit dependency licences | context: Exclude dev-only packages.
14:32:02 start    | Audit dependency licences
14:32:03 think    | I should list the dependency graph first.
14:32:05 tool     | -> terminal({"command": "flutter pub deps --json"})
14:32:08 result   | terminal ok 3.1s: {"packages": [...]}
14:32:09 tool     | -> read_file({"path": "pubspec.lock"})
14:32:09 result   | read_file ERROR 0.2s: file not found
14:32:11 assistant| 41 of 48 runtime packages are MIT/BSD/Apache.
14:32:12 final    | status=completed duration=11.0s summary: Done.
''';

    test('parses roles and drops the header', () {
      final lines = ThreadTailLine.parseAll(tail);

      expect(lines.map((line) => line.role), [
        'user',
        'start',
        'think',
        'tool',
        'result',
        'tool',
        'result',
        'assistant',
        'final',
      ]);
      expect(lines.first.time, '14:32:01');
      expect(lines[7].text, '41 of 48 runtime packages are MIT/BSD/Apache.');
    });

    test('reads tool starts and results', () {
      final lines = ThreadTailLine.parseAll(tail);

      expect(lines[3].toolStart, (
        name: 'terminal',
        args: '{"command": "flutter pub deps --json"}',
      ));
      final ok = lines[4].toolResult!;
      expect(ok.name, 'terminal');
      expect(ok.isError, isFalse);
      expect(ok.seconds, 3.1);
      final failed = lines[6].toolResult!;
      expect(failed.isError, isTrue);
      expect(failed.result, 'file not found');
    });

    test('a first line cut by the 16 KB window is dropped', () {
      final lines = ThreadTailLine.parseAll(
        'ckages": [...]}\n14:32:09 tool     | -> read_file({"path": "a"})\n',
      );

      expect(lines.single.role, 'tool');
    });
  });

  group('roster and capability parsing', () {
    test('session.info without a capability list advertises nothing', () {
      final info = ThreadSessionInfo.parse({'model': 'x', 'cwd': '/tmp'})!;
      expect(info.capabilities, isEmpty);
      expect(info.coordinatorMode, isNull);
    });

    test('session.info with keys and the coordinator flag', () {
      final info = ThreadSessionInfo.parse({
        'coordinator_mode': true,
        'capabilities': ['threads.roster', 'coordinator_mode', 7],
      })!;
      expect(info.capabilities, {'threads.roster', 'coordinator_mode'});
      expect(info.coordinatorMode, isTrue);
    });

    test('a roster row without an id is skipped', () {
      final roster = ThreadRosterSnapshot.parse({
        'subagents': [
          {'goal': 'no id'},
          {'subagent_id': 'sa-1', 'pending_question': null},
        ],
      });
      expect(roster.threads.single.subagentId, 'sa-1');
      expect(roster.threads.single.pendingQuestion, isNull);
    });

    test('approval attribution is present only for a thread', () {
      expect(ThreadApprovalAttribution.parse({'command': 'ls'}), isNull);
      final thread = ThreadApprovalAttribution.parse({
        'command': 'rm -rf build',
        'subagent_id': 'sa-0',
        'goal': 'Check CI matrix',
      })!;
      expect(thread.subagentId, 'sa-0');
      expect(thread.goal, 'Check CI matrix');
    });
  });
}
