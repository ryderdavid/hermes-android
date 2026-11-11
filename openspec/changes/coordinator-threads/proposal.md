# Proposal

## Why

Long multi-part requests block a chat today. The Hermes gateway can already
run background subagents and keep talking: `delegate_task(background=true)`
returns a handle at once, and the result arrives later as a new parent turn.
It can also list, tail, steer and interrupt those subagents, and it stores
each child's transcript. The Android app shows almost none of this. A
delegated task is one collapsible card of spinners, and the child's work
can't be opened, steered or stopped. On top of that, a child can only speak
once, when it finishes. It cannot ask the main chat a question or report
progress mid-run. Claude's coordinator pattern needs both halves: one main
chat for the discussion, and threads that run on their own and talk back to
it.

## What Changes

- **Threads roster in the chat.** A strip under the context header lists
  the chat's threads with their state (running, needs you, done, failed).
  An "All" sheet adds the slot count, earlier threads, Pause and Stop all.
  It replaces the `GatewaySubagentCard` spinner list. Mockups 02 and 03.
- **Thread view.** A full screen for one thread: the task the coordinator
  gave it, a live tail of its tool activity and text (`subagent.tail` while
  running, the stored transcript once finished), and a steer bar that sends
  `subagent.steer`, with Stop (`subagent.interrupt`). Mockup 04. It builds on
  upstream's read-only delegated-task overlay (fork group U06).
- **Thread cards in the main chat.** The coordinator's turn leaves a
  "Started N threads" card. Each completion is drawn as a report card with
  Open thread and Continue, instead of the raw task-source text. Mockups 02
  and 06.
- **Coordinator mode.** A per-chat toggle in the chat menu. When it's on,
  the gateway gives the main agent coordinator instructions: answer the user
  directly, and send work longer than a few steps to background threads.
  The app bar shows a Coordinator label. Mockup 07.
- **Approvals and notifications from threads.** An approval raised by a
  thread opens in its parent chat and names the thread. Thread questions
  and finished reports notify like turn completions. Mockup 08.
- **Gateway (cross-repo, `ryderdavid/hermes-agent` fork).**
  - A child-side `message_parent` tool, with `update` and `question` kinds,
    delivered through the existing async-delegation completion queue.
  - A reply path for answering a question in the thread.
  - Continuable threads: a finished child can take a follow-up, and its
    answer is reported back to the parent again.
  - A coordinator-mode session flag that injects the coordinator
    instructions.
  - A capability flag so the app can tell which gateways support each of
    these. Mockups 05 and 06.

No **BREAKING** changes. On gateways without the new capabilities, the app
falls back to today's behaviour plus whatever the existing `subagent.*` RPCs
allow.

## Capabilities

### New Capabilities

- `agent-threads`: how the app lists, opens, follows, steers and stops a
  chat's delegated threads, and how a thread's start, completion and
  approvals appear in the parent chat.
- `coordinator-mode`: the per-chat coordinator setting: how it's turned on,
  stored, sent to the gateway and shown.
- `thread-messaging`: the parent–thread message contract: interim updates
  and questions from a running thread, replies to them, and follow-ups to a
  finished thread. It covers both the gateway behaviour and how the app
  draws it.

### Modified Capabilities

None. The composer, theming and chat-icon specs are unchanged. The steer
bar is a separate control, not a composer mode.

## Impact

- **App**:
  - `lib/core/screens/chat_screen.dart` (event routing, list items, menu,
    app bar)
  - `lib/core/widgets/gateway_insight_card.dart` (`GatewaySubagentCard` is
    replaced)
  - new `lib/core/widgets/thread_*.dart` and
    `lib/core/screens/thread_screen.dart`
  - `lib/core/models/gateway_insight.dart` (thread model)
  - `lib/core/services/ws_client.dart` and `desktop_gateway_client.dart`
    (new RPCs and async event types)
  - `capability_registry.dart`
  - `turn_notification_service.dart`
  - per-chat settings storage
  - all `lib/l10n/app_*.arb`
- **Dependency**: fork group U06 (bead `hmy-5na.6`, upstream's delegated
  inspection and background report cards) must land first. The thread view
  and report cards extend it.
- **Gateway** (`~/Code/hermes-agent`):
  - `tools/async_delegation.py`, `tools/delegate_tool*.py`
  - `tui_gateway/methods_subagents.py` and `methods_session.py`
  - `tui_gateway/session_notifications.py`
  - the capability advertisement in `session.info`
- **Cost and load**: more agents run at once. The default cap of 3
  background children stays, and the roster shows it.
