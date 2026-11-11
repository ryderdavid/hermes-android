# Design

## Context

See proposal.md for motivation. What exists today, by side:

**Gateway** (`~/Code/hermes-agent`, fork of NousResearch hermes-agent):
- **Delegation.** `delegate_task` spawns child `AIAgent`s with a fresh
  context. `background=true` dispatches on a daemon pool (default cap 3),
  returns a handle, and later pushes a `type="async_delegation"` event onto
  `process_registry.completion_queue`. The gateway drains that queue only
  while the parent session is idle, so a result always arrives as a new
  parent turn. The queue de-dups, persists in a ledger, and is replayed
  after a restart (`tools/async_delegation.py`,
  `tui_gateway/session_notifications.py`).
- **Child sessions.** Each child's transcript is stored as a session with
  `parent_session_id` and `model_config._subagent_id`
  (`tools/delegate_tool_sessions.py`).
- **RPCs.** `subagent.list`, `subagent.roster`, `subagent.tail` (bounded
  16 KB snapshot), `subagent.interrupt` and `subagent.steer` (delivered at
  the child's next iteration), plus `delegation.status` and
  `delegation.pause`. `delegation.pause` is process-global
  (`ws_legacy_fallback._PROCESS_GLOBAL`).
- **Events.** `subagent.spawn_requested`, `start`, `thinking`, `tool`,
  `progress` and `complete` stream to the parent's clients.
- **Child approvals.** These never reach a person. They are auto-denied by
  default, or auto-approved when `delegation.subagent_auto_approve` is set
  (`delegate_tool_config._get_subagent_approval_callback`).
- **No child-to-parent channel.** A child can't message its parent before
  it finishes.

**App** (this repo):
- `DesktopGatewayClient` routes `subagent.*` and `background.complete` as
  async events. `ChatScreen._upsertSubagent` folds them into
  `GatewaySubagentActivity`, which `GatewaySubagentCard` draws as an
  expansion tile of spinners.
- Child sessions are hidden (`is_internal_child`).
- The app calls none of the `subagent.*` RPCs.

**Upstream group U06** (bead `hmy-5na.6`, not yet in the fork) adds:
- `DelegatedTaskController` and `delegated_task_history.dart`: bounded,
  authenticated, read-only history GETs with verified compression lineage.
- `delegated_task_timeline.dart`: a modal route that keeps the parent chat
  mounted.
- `BackgroundReport` and `background_report_card.dart`: classifies
  completion turns by server annotation.

U06 deliberately does not control child work.

The mockups in `mockups/` are rendered with the app's real theme and
widgets. They reuse `MessageBubble`, `GatewayActivityCard`,
`ChatContextHeader`, `ChatMark`, `ChatComposer` and `GatewayApprovalDialog`
unchanged. The new pieces use only `ColorScheme` roles and `HermesTokens`.
Re-render with the procedure in `mockups/README.md`.

## Goals / Non-Goals

**Goals:**
- Reuse the gateway's async-delegation queue for every child-to-parent
  message, so de-dup, persistence and restart replay come for free.
- Build the thread view and report cards on U06, not alongside it, so
  upstream rebases stay cheap.
- Add new UI in new files, and keep `chat_screen.dart` edits to hook
  points. Upstream churns that file most.
- Gate every feature on an advertised capability, so the app works against
  stock gateways.

**Non-Goals:**
- Threads that talk to each other. Every message goes through the parent.
- Running threads on the phone. Threads always run on the gateway.
- Choosing a model per thread from the phone. Threads use the gateway's
  delegation config.
- A separate "thread" entry in the Chats list. Threads live inside their
  parent chat.

## Decisions

**D1. The thread view extends U06's timeline route instead of being a new
screen.** U06 already solves authenticated history reads, compression
lineage and the "keep the parent mounted" route, and that route is how the
"parent state preserved" scenario is met. We add three things on top:
- a live source: `subagent.tail` plus the `subagent.*` events;
- the steer bar;
- the full-screen chrome from mockup 04.

*Alternative:* a standalone `ThreadScreen` reading child sessions through
the existing session APIs. Rejected because it duplicates U06's lineage
checks and would conflict on every upstream sync.

**D2. Data flow for thread state.**
- `subagent.roster` seeds the state when the chat opens and after each
  reconnect.
- The `subagent.*` events update it incrementally.
- While a running thread's view is visible, `subagent.tail` is polled every
  2 s and stops when the view closes.
- Once a thread finishes, the view switches to U06's stored-history reads.

A new `AgentThreadsController`, one per chat, owns the roster model
(`AgentThread`: id, delegation id, goal, model, state, tool count, start
time, pending question). It replaces `_subagentActivities` in
`ChatScreen`. *Alternative:* events only. Rejected because events missed
while disconnected would leave stale spinners, which is the bug the roster
RPC exists to fix.

**D3. The roster strip sits under `ChatContextHeader`, not in the app
bar.** Chip widths need horizontal room. The strip hides when there are no
threads, so chats that don't use threads look exactly as they do today.
Waiting threads sort first and use `tertiaryContainer` (mockup 02).
*Alternative:* only the inline "Started N threads" card. Rejected because
it scrolls away, and a long conversation then hides which threads still
need you.

**D4. The steer bar is its own control, not a mode of `ChatComposer`.**
Steering takes text only: no attachments, voice or model picker. Keeping
it separate leaves the `chat-composer` spec and goldens untouched. It
reuses the input decoration from `hermesTheme`.

**D5. Coordinator mode is a gateway session flag, not prompt text.**
- **Server.** A new `session.mode.set {coordinator: bool}` stores the flag
  on the session. While it is set, the gateway:
  - appends a coordinator instruction block to the main agent's system
    prompt (maintained in the gateway repo next to other prompt blocks);
  - defaults that session's `delegate_task` to `background=true`.
- **App.** The per-chat preference is the source of truth on the phone.
  It is re-applied whenever the app binds to the session, so a session
  resumed from another client gets the phone's choice the next time the
  phone sends.

*Alternative:* add the instructions to the user's message on the phone.
Rejected because it pollutes the transcript, breaks on other clients, and
the spec forbids it.

**D6. The child's `message_parent` tool uses the existing completion
queue.** Children get one new tool:

    message_parent(kind: "update" | "question", text, options?)

- **`update`** enqueues an `async_delegation_message` event carrying the
  `subagent_id` and `delegation_id`, and returns immediately. Updates are
  limited per thread (default 1 per 60 s), and extra updates are merged
  into the next delivery.
- **`question`** enqueues the same kind of event with a `question_id`,
  then blocks that child on a per-question future. The default wait limit
  is 15 minutes, set by `delegation.question_timeout`. On timeout the tool
  returns `{"answered": false}`.
- **Answers** arrive through a new
  `subagent.reply {subagent_id, question_id, text, answered_by: "user" | "coordinator"}`.
  For "Let coordinator decide", the app sends one parent prompt asking the
  coordinator to answer, and the gateway resolves the reply from that
  turn's tool call.

Because the queue drains only while the parent is idle, a mid-turn update
waits until the turn ends. The spec states this. *Alternative:* inject
into the parent mid-turn like a steer. Rejected because it interleaves
messages into the user-visible reply in progress, and the queue already
gives exactly-once delivery.

**D7. Continuable threads are dispatched as new async delegations that
reuse the child's lineage.**

    subagent.continue {subagent_id, text}

This call:
1. resolves the child's newest stored segment with
   `stored_child_session`;
2. builds a child agent from that history;
3. dispatches it through the normal async path with the same
   `subagent_id`.

So it counts against slots, queues when slots are full, and reports back
the usual way.

**D8. Thread approvals go to a person through the parent session.** A new
`delegation.subagent_approval: ask` mode, the default when the parent
session has a connected client, replaces auto-deny. It raises the request
on the parent session's existing server-request channel, adding
`subagent_id` and `goal` to the payload. The app's current per-session
approval routing then delivers it to the parent chat, and
`GatewayApprovalDialog` shows the thread name (mockup 08). With no
connected client, the existing auto-deny/approve behaviour stays.

**D9. Capabilities.** `session.info` advertises:
- `threads.roster`
- `threads.steer`
- `threads.messages`
- `threads.continue`
- `threads.approvals`
- `coordinator_mode`

`CapabilityRegistry` exposes them. Controls hide or disable per the specs.
Stock gateways advertise none, but already serve the roster, steer and
interrupt RPCs. For those, the app probes `subagent.roster` once per
connection and enables Phase 1 if the probe succeeds.

**D10. Report cards come from server annotation.** The
`async_delegation` completion turn carries `subagent_id`, `goal`, status,
tool count and duration. U06's `BackgroundReport` classifier is extended
to read these into a thread report. Prefix matching on the task-source
text is used only for legacy turns, as U06 already does.

## Risks / Trade-offs

- **U06 has not landed yet** → Phase 1 is blocked on `hmy-5na.6`. The roster
  strip, sheet and coordinator toggle don't depend on U06 and can start
  first. The task order reflects this.
- **Upstream churn in `chat_screen.dart`** → New code lives in
  `agent_threads_controller.dart`, `thread_*.dart` widgets and the U06
  timeline. `ChatScreen` gains only the controller, one list item type, a
  menu item and the strip slot.
- **More parent turns cost more tokens** → Updates are rate-limited and
  merged (D6), and report cards carry summaries rather than full child
  output. The roster states the slot limit.
- **A blocked question holds a background slot** → The wait limit is
  bounded, the slot count shows in the sheet, and expired questions resume
  the child.
- **Pause is gateway-wide** → The spec makes the UI say so. We don't add a
  per-session pause.
- **Two clients on one session (TUI and phone)** → Gateway records are
  scoped by session and transport (`_subagent_transport_matches`). Steer
  and stop go through the same owner checks. A reply to a question is
  accepted once, and later replies are rejected with a clear error.
- **The gateway fork drifts further from NousResearch** → This is an
  isolated fork, and nothing is sent upstream. Gateway changes are kept
  additive (one tool, three RPCs, one session flag, an approval mode,
  capability keys), so pulling NousResearch fixes into the fork stays
  cheap.

## Migration Plan

1. **Phase 1a (app only, no U06 dependency).** Capability probe,
   `AgentThreadsController`, roster strip and sheet, steer and stop
   controls, coordinator toggle stored but disabled until the gateway
   supports it.
2. **Phase 1b (after U06).** Thread view on the U06 route, "Started N
   threads" card, report cards.
3. **Phase 2 (gateway fork, then app).** `session.mode.set`, the
   coordinator prompt, `message_parent`, `subagent.reply`,
   `subagent.continue`, approvals in `ask` mode, capability keys. Then the
   app's update and question cards, Continue, thread approvals and
   notifications.

Each phase ships as its own `-you.<n>` release. Rollback: every feature is
behind a capability. On a gateway rolled back to stock, the app falls back
to the Phase 1a probe or to today's read-only list.

## Open Questions

- The default question wait limit (15 min) and update rate (1 per 60 s)
  are starting values. Tune them after device use. Neither changes the
  specs.
