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
- **RPCs.** `subagent.list` (the per-chat roster of live children),
  `subagent.roster` (an app-wide count per stored conversation, with no
  `session_id`), `subagent.tail` (bounded 16 KB snapshot),
  `subagent.interrupt` and `subagent.steer` (delivered at the child's next
  iteration), plus `delegation.status` and `delegation.pause`.
  `delegation.pause` is process-global
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

**Upstream group U06** (delegated-task inspection and background report
cards) is not in this fork and will not be merged. Nothing here depends on
it: the thread view, the report card and the started-threads card are
built in this change, on what the fork already has:
- the session-messages API (`ApiClient.getMessages`), which reads any
  stored session by id, a child session included;
- the chat's display projection (`buildChatDisplayItems`) and its activity
  rows, fold line and detail sheet.

The mockups in `mockups/` are rendered with the app's real theme and
widgets. They reuse `MessageBubble`, `GatewayActivityCard`,
`ChatContextHeader`, `ChatMark`, `ChatComposer` and `GatewayApprovalDialog`
unchanged. `GatewayActivityCard` has since been replaced by the activity
rows (`ActivityRow`, `TurnFoldLine`); the thread view uses those. The new pieces use only `ColorScheme` roles and `HermesTokens`.
Re-render with the procedure in `mockups/README.md`.

## Goals / Non-Goals

**Goals:**
- Reuse the gateway's async-delegation queue for every child-to-parent
  message, so de-dup, persistence and restart replay come for free.
- Draw a thread with the same projection and rows as the main chat, so a
  thread reads like a chat and there is one renderer to maintain.
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

**D1. The thread view is its own screen, `ThreadScreen`, reading child
sessions through the existing session-messages API.** It does not use
upstream group U06, which is not in this fork.
- **Route.** `ThreadScreen` is pushed over the chat as an ordinary page
  route. `ChatScreen` stays mounted underneath, which is how the "parent
  state preserved" scenario is met.
- **Live.** While the thread runs and the view is visible,
  `ThreadViewController` polls `subagent.tail` every 2 s, and again as soon
  as a `subagent.*` event reports a new step. The tail is an operational
  log, one line per event; it is parsed into the same message and
  tool-activity shapes the chat uses.
- **Finished.** The view loads the child's stored transcript with
  `ApiClient.getMessages(child_session_id)`, the id the roster and the
  `subagent.*` events provide, in pages of 200 rows up to 5 pages.
- **Rendering.** Both sources go through `buildChatDisplayItems` and are
  drawn with `ActivityRow`, `TurnFoldLine`, `MessageBubble` and the activity
  detail sheet. The view is read-only apart from the steer bar: no composer.
- **Partial or unavailable history is labelled, not an error screen.** A
  failed older page, or a transcript longer than the page budget, shows
  what loaded with an "earlier steps are unavailable" line. No stored
  session, or a failed first page, keeps the last live tail and says the
  stored transcript could not be loaded, with Retry.

*Alternative:* build on U06's `DelegatedTaskController` and timeline route.
Rejected: U06 is not in the fork and merging it is out of scope. The cost
is that the view relies on the gateway's own lineage handling for child
sessions rather than U06's client-side checks.

**D2. Data flow for thread state.**
- `subagent.list {session_id}` seeds the state every time the chat binds
  its gateway session: when it opens and after each reconnect. (In this
  gateway the per-chat roster is `subagent.list`; `subagent.roster` is an
  app-wide count and is not used.) Its `pending_question` is the truth
  after a reconnect, and its `queued` list names follow-ups waiting for a
  slot. A thread the app still shows as active but the roster no longer
  lists is marked finished, or failed when `delegations` records it.
- The `subagent.*` events update it incrementally: the progress events,
  `subagent.question` for the question lifecycle (pending, answered,
  expired, cancelled; live-only) and `subagent.message` when an update or
  question is delivered as a parent turn.
- While a running thread's view is visible, `subagent.tail` is polled every
  2 s and stops when the view closes.
- Once a thread finishes, the view switches to stored-history reads (D1).

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
- **Server.** A new `session.mode.set {session_id, coordinator: bool}`
  stores the flag on the session and reports it as
  `session.info.coordinator_mode`. While it is set, the gateway:
  - appends a coordinator instruction block to the main agent's system
    prompt (maintained in the gateway repo next to other prompt blocks);
  - defaults that session's `delegate_task` to `background=true`.
- **App.** The per-chat preference is the source of truth on the phone.
  While it is on, `session.mode.set` is sent on toggle, on every session
  bind, and before a prompt when the session was not yet bound (so the
  first prompt of a new chat already runs in the mode). The call is
  idempotent on the gateway.

*Alternative:* add the instructions to the user's message on the phone.
Rejected because it pollutes the transcript, breaks on other clients, and
the spec forbids it.

**D6. The child's `message_parent` tool uses the existing completion
queue.** Children get one new tool:

    message_parent(kind: "update" | "question", text, options?)

- **`update`** enqueues a thread message carrying the `subagent_id` and
  `delegation_id`, and returns immediately. Updates are limited per thread
  (default 1 per 60 s), and extra updates are merged into the next
  delivery.
- **`question`** enqueues the same kind of message with a `question_id`,
  then blocks that child on a per-question future. The default wait limit
  is 15 minutes, set by `delegation.question_timeout`. On timeout the tool
  returns `{"answered": false}`.
- **What the client sees.** The parent turn's user row has
  `display_kind: "async_delegation_message"` and an annotation
  (`display_metadata`) with `type: "async_delegation_message"`. The same
  annotation is the payload of a live `subagent.message` event when the
  turn starts. Question state changes arrive as `subagent.question`
  events (`pending`, `answered`, `expired`, `cancelled`); they are
  live-only, so after a reconnect the roster's `pending_question` decides
  whether a question card is still open.
- **Answers** arrive through a new
  `subagent.reply {session_id, subagent_id, question_id, text, answered_by: "user" | "coordinator"}`.
  The first reply wins; a later one is rejected with error code `4090`
  and a message that says how the question was closed. For "Let
  coordinator decide", the app sends one ordinary parent prompt asking the
  coordinator to answer; the coordinator answers with its own
  `delegate_task(action="reply")` call, and the app learns the outcome
  from the `subagent.question` event. The app does not call
  `subagent.reply` on that path.
- **Rows without the annotation.** The mobile REST history
  (`/api/sessions/<id>/messages`) returns `display_kind` but not
  `display_metadata`. For such a row the app rebuilds the card from the
  turn's scaffold text (`[THREAD UPDATE — <id>]`,
  `[THREAD QUESTION — <id>, question <qid>]`), matched only at the very
  start of the text.

Because the queue drains only while the parent is idle, a mid-turn update
waits until the turn ends. The spec states this. *Alternative:* inject
into the parent mid-turn like a steer. Rejected because it interleaves
messages into the user-visible reply in progress, and the queue already
gives exactly-once delivery.

**D7. Continuable threads are dispatched as new async delegations that
reuse the child's lineage.**

    subagent.continue {session_id, subagent_id, text}

This call:
1. resolves the child's newest stored segment with
   `stored_child_session`;
2. builds a child agent from that history;
3. dispatches it through the normal async path with the same
   `subagent_id`.

So it counts against slots and reports back the usual way. The result is
`dispatched`, `queued` (no free slot; with its place in line) or
`rejected` (with the reason). A queued follow-up is listed under
`subagent.list` → `queued` until it starts.

**D8. Thread approvals go to a person through the parent session.** A new
`delegation.subagent_approval: ask` mode, the default when the parent
session has a connected client, replaces auto-deny. A thread's approval is
the parent session's normal `approval` server request with `subagent_id`
and `goal` added to its params. The app's current per-session
approval routing then delivers it to the parent chat, and
`GatewayApprovalDialog` shows the thread name (mockup 08). With no
connected client, the existing auto-deny/approve behaviour stays.

**D9. Capabilities.** `session.info.capabilities` is a list of keys, sent
in the `session.info` event and in the `info` of `session.create` and
`session.resume` results:
- `threads.roster`
- `threads.steer`
- `threads.messages`
- `threads.continue`
- `threads.approvals`
- `coordinator_mode`

`CapabilityRegistry` exposes them. Controls hide or disable per the specs.
A `session.info` without the list is "no news", not a withdrawal; only a
new connection forgets what was advertised. Stock gateways advertise none,
but already serve the roster, tail, steer and interrupt RPCs. For those,
the app probes `subagent.list` once per connection, on the chat's first
session bind, and enables the roster, thread view, steer and stop if the
probe succeeds. An unknown-method answer leaves the read-only task list in
place. A reconnect probes again.

**D10. Report cards come from server annotation.** The completion turn's
user row has `display_kind: "async_delegation_complete"` and
`display_metadata.threads[]` with `subagent_id`, `goal`, `status`,
`tool_count` and `duration_seconds` per thread. `ThreadReportAnnotation`
(in `thread_wire.dart`) reads these into a report; the projection emits a
`ChatThreadReportItem`, drawn by `ThreadReportCard`. The annotation carries
no result text, so the summary is always read from the row's content.
Matching on the gateway's own header (`[ASYNC DELEGATION COMPLETE — …]`,
`BATCH COMPLETE`, `TASK FAILED`) at the very start of the text is used
only when the row has no annotation: a legacy turn, or a row read through
the REST history, which omits `display_metadata`. A person's message that
quotes a report further down keeps its bubble. A report with no
`subagent_id` is matched to the roster by delegation, then by goal; with
no match it offers neither Open thread nor Continue.

The "Started N threads" card is not a stored turn. The projection places
each thread in the turn that was running when the thread started (the last
turn whose user message is no later than the thread's start), and
`AgentThreadsController` supplies the rows' live state.

## Risks / Trade-offs

- **The live tail is a log, not a transcript** → It is the last 16 KB, with
  each line cut to a few hundred characters, and it shows no tool output.
  The view says when the tail no longer reaches the thread's first steps,
  and the full transcript replaces it once the thread finishes.
- **The stored transcript may be missing** → A report read after an app
  restart names the thread but not its child session, and the gateway
  forgets finished threads. The view then opens with the task and the
  report's outcome and labels the transcript as unavailable.
- **Card placement uses clocks** → The started-threads card is placed by
  comparing the thread's start with the turns' start times. A phone clock
  that differs from the gateway's by more than the gap between two turns
  can put the card one turn off.
- **Gateway-started turns** → A thread report or message starts a parent
  turn the chat did not submit. The chat re-reads its history once it is
  idle after such an event, so the card and the coordinator's reply appear
  without a manual refresh. This only runs in chats that have threads.
- **One approval at a time per chat** → `DesktopGatewayClient` rejects an
  approval that arrives while another is open in the same chat. Threads
  make concurrent approvals more likely; the second one is refused, not
  queued.
- **Recovery-v2 drafts** → Thread RPCs and `session.mode.set` use the
  legacy Desktop transport. A new chat on a gateway that offers the
  experimental recovery-v2 transport applies them once it is reopened as a
  stored chat. The coordinator-threads gateway does not offer that
  transport.
- **Upstream churn in `chat_screen.dart`** → New code lives in
  `agent_threads_controller.dart`, `thread_*.dart`, `threads_*.dart` and
  `chat_threads_binding.dart`. `ChatScreen` gains only the binding, the
  thread list items, a menu item, the app bar label and the strip slot.
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

1. **Phase 1a (app only).** Capability probe, `AgentThreadsController`,
   roster strip and sheet, steer and stop controls, coordinator toggle
   stored but disabled until the gateway supports it.
2. **Phase 1b (app only).** `ThreadScreen` with the live tail and stored
   transcript, "Started N threads" card, report cards. No dependency on
   U06.
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
