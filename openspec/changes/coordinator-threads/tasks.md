# Tasks

Phases follow design.md, Migration Plan: 1a (groups 1–4) has no dependency
on U06. 1b (groups 5–6) needs bead `hmy-5na.6`. Phase 2 (groups 7–10) needs
the gateway fork. Gateway tasks run in `~/Code/hermes-agent`, using that
repo's own checks.

Beads: epic `hmy-6qr`; group N is `hmy-6qr.N` (CT1–CT10). Dependencies are
set on the board (`bd show hmy-6qr`).

## 1. Thread transport and capabilities (app)

- [x] 1.1 Add `WsClient` wrappers for `subagent.roster`, `subagent.tail`,
  `subagent.steer`, `subagent.interrupt`, `delegation.status` and
  `delegation.pause`. Each wrapper parses gateway errors through
  `JsonRpcError`. Verify with unit tests against a fake socket that cover
  success, error and missing-result cases.
- [x] 1.2 Extend `CapabilityRegistry` with the D9 keys (`threads.roster`,
  `threads.steer`, `threads.messages`, `threads.continue`,
  `threads.approvals`, `coordinator_mode`), read from `session.info`. On
  stock gateways, probe `subagent.roster` once per connection. Verify with
  tests: advertised, probe success, probe failure, reconnect re-probe.
- [x] 1.3 Route the async event types needed by threads through
  `DesktopGatewayClient` without changing the existing `subagent.*`
  delivery. Verify that the existing `desktop_gateway_client` tests still
  pass, and add one test asserting that roster-relevant events reach the
  listener after a reconnect.

## 2. Threads controller, roster strip and sheet (app)

- [ ] 2.1 Add `AgentThread` and `AgentThreadsController` (one per chat).
  The controller seeds from `subagent.roster` on open and reconnect,
  applies `subagent.*` events, derives running/needs-you/done/failed, and
  sorts waiting threads first. Replace `_subagentActivities` in
  `ChatScreen` with it. Verify with controller unit tests: seed, event
  merge, a missed event repaired by re-seed, sort order.
- [ ] 2.2 Build `ThreadsStrip` (mockup 02) under `ChatContextHeader`. It is
  hidden with zero threads, uses `tertiaryContainer` for waiting threads,
  and opens the thread on tap and the sheet from "All". Verify with widget
  tests for hidden/visible/sorted states, plus new goldens
  `threads_strip_*` across the matrix.
- [ ] 2.3 Build `ThreadsSheet` (mockup 03): slot usage from
  `delegation.status`, stop one, Stop all with confirmation, earlier
  threads, and Pause new threads labelled as gateway-wide. Verify with
  widget tests for each action's RPC call and confirmation, plus goldens
  `threads_sheet_*`.
- [ ] 2.4 Keep the read-only fallback. On a gateway with no thread
  capability and a failed probe, render today's `GatewaySubagentCard`
  unchanged. Verify that the existing goldens are unchanged and add a
  fallback widget test.
- [ ] 2.5 Add every new string to all `lib/l10n/app_*.arb` catalogues and
  run `flutter gen-l10n`. Verify `flutter analyze` reports no issues and
  `tools/check_no_hardcoded_colors.sh` passes.

## 3. Coordinator toggle, app side (app)

- [ ] 3.1 Store coordinator mode per chat (new preference store, following
  `chat_model_override_store.dart`), plus a "new chats use coordinator
  mode" default in Settings. Include both in `config_backup.dart`. Verify
  with store tests and a backup round-trip test.
- [ ] 3.2 Add the Coordinator mode `CheckedPopupMenuItem` with its subtitle
  to the chat menu (mockup 07), and the Coordinator label under the app bar
  title (mockup 02). Disable it with the "gateway must be updated" subtitle
  when `coordinator_mode` is absent. Verify with widget tests for the
  enabled/disabled/checked states and the app bar label.
- [ ] 3.3 Send `session.mode.set` on toggle and on every session bind while
  the mode is on. Never change prompt text. Verify with a fake-gateway test
  that the RPC is sent on bind and toggle, and that prompt payloads are
  byte-identical with the mode on and off.

## 4. Phase 1a release

- [ ] 4.1 Run `flutter analyze`, `flutter test`, the colour lint, and
  `flutter build apk --debug`. Install the debug build and check the strip,
  sheet, stop and Stop all against a stock gateway running real background
  delegations (`needs-device-check`). Record the result in the bead.
- [ ] 4.2 Bump to the next `-you.<n>`, write `docs/releases/v<version>.md`,
  then build, tag and publish per `docs/FORK.md`. Verify the in-app update
  check offers it on the phone.

## 5. Thread view on the U06 route (app, after `hmy-5na.6`)

- [ ] 5.1 Extend U06's `DelegatedTaskController` with a live source:
  `subagent.tail` polled every 2 s while the view is visible and the thread
  is running, plus the controller's `subagent.*` events. Hand over to
  stored-history reads on completion. Verify with controller tests: polling
  starts and stops with visibility, hand-off on completion, partial history
  labelled.
- [ ] 5.2 Give the U06 timeline route the full-screen thread chrome
  (mockup 04): title, "Thread of <chat>", state, tools, elapsed time, model,
  live indicator, and a task card. Tool activity uses `GatewayActivityCard`.
  Verify with widget tests and `thread_view_*` goldens, and with a test
  that the parent draft and scroll offset survive opening and closing the
  view.
- [ ] 5.3 Build `ThreadSteerBar` (D4). Steer sends `subagent.steer` and
  shows acknowledged / did-not-land, keeping the text when it does not land.
  Stop sends `subagent.interrupt`. The bar is disabled when the thread is
  not accepting steering. Verify with widget tests for each outcome.

## 6. Thread cards in the parent chat (app, after `hmy-5na.6`)

- [ ] 6.1 Add the "Started N threads" card as a chat display item, driven
  live by `AgentThreadsController` (mockup 02). Verify with
  display-item-builder tests and a widget test that row states update.
- [ ] 6.2 Extend U06's `BackgroundReport` classifier to read the
  `async_delegation` annotation (subagent id, goal, status, tools,
  duration) and render `ThreadReportCard` (mockup 06). The Continue action
  stays hidden until `threads.continue`. Verify with classifier tests
  (annotated, legacy, mixed human text left alone) and
  `thread_report_card_*` goldens.
- [ ] 6.3 Run the full gates, check on device against a stock gateway
  (`needs-device-check`), and release the next `-you.<n>` per
  `docs/FORK.md`.

## 7. Coordinator mode, gateway side (hermes-agent fork)

- [ ] 7.1 Add `session.mode.set {coordinator}`: store the flag on the
  session and expose it in `session.info`. Verify with gateway tests for
  set, get and persistence across resume.
- [ ] 7.2 While the flag is set, append the coordinator instruction block to
  the main agent's system prompt and default `delegate_task` to
  `background=true` for that session. Verify with tests that the prompt
  includes the block only while the flag is set, that the background
  default applies, and that clearing the flag leaves running children
  untouched.
- [ ] 7.3 Advertise the D9 capability keys in `session.info`. Verify with a
  contract test in `tui_gateway/contracts`.

## 8. Thread messaging, gateway side (hermes-agent fork)

- [ ] 8.1 Add the child-only `message_parent` tool. `update` enqueues an
  `async_delegation_message` on the completion queue, rate-limited
  (default 1 per 60 s, with excess merged). Verify with tests for delivery
  when the parent is idle, holding until the turn ends, exactly-once across
  a simulated restart, and merging.
- [ ] 8.2 Implement `question`: enqueue with a `question_id` and block the
  child on a future with `delegation.question_timeout` (default 15 min);
  add the `subagent.reply` RPC, which accepts the first reply only and
  records `answered_by`. Verify with tests for user reply, coordinator
  reply, timeout returning `answered: false`, and a duplicate reply
  rejected.
- [ ] 8.3 Add `subagent.continue {subagent_id, text}`: resolve the child's
  stored lineage, rebuild the child, dispatch async with the same
  `subagent_id`, and queue when slots are full. Verify with tests for
  continuing from stored history, the slot-full queue, and the report
  arriving as a new parent turn.
- [ ] 8.4 Add `delegation.subagent_approval: ask` (the default when the
  parent has a connected client). It raises the child's approval on the
  parent's server-request channel with `subagent_id` and `goal`, and falls
  back to auto-deny/approve with no client. Verify with tests for routing,
  answer delivery to the right child, and the no-client fallback.
- [ ] 8.5 Document the new tool, RPCs and config keys in the gateway repo's
  docs, and open a PR on `ryderdavid/hermes-agent`. Verify the gateway
  repo's own lint and test suite pass.

## 9. Thread messaging, app side (app, after group 8 is deployed)

- [ ] 9.1 Render `async_delegation_message` turns as `ThreadMessageCard`
  (mockup 05). Updates offer Open thread. Questions use the emphasised card
  with Reply and Let coordinator decide, and the thread shows "needs you".
  Verify with widget tests and `thread_message_card_*` goldens.
- [ ] 9.2 Make Reply send `subagent.reply` (answered_by user). Make "Let
  coordinator decide" send the coordinator prompt. Have the card record the
  answer, who answered, or expiry. Verify with fake-gateway tests for each
  path, including a rejected duplicate reply.
- [ ] 9.3 Make Continue on report cards and in the thread view send
  `subagent.continue`, and show the queued state when slots are full.
  Verify with widget tests gated on `threads.continue`.
- [ ] 9.4 Thread approvals: when an approval payload carries `subagent_id`,
  name the thread in `GatewayApprovalDialog` (mockup 08) and answer only
  that request. Verify with an approval routing test and
  `approval_sheet_thread_*` goldens.
- [ ] 9.5 Thread notifications in `turn_notification_service.dart` for
  finished, failed and question events, honouring the privacy setting and
  deep-linking to the parent chat at the card. Verify with notification
  service tests for content and private modes.
- [ ] 9.6 Add every new string to all `app_*.arb` catalogues and run
  `flutter gen-l10n`. Verify with analyze and the colour lint.

## 10. End-to-end verification and release

- [ ] 10.1 On the phone against the updated gateway (`needs-device-check`):
  turn on coordinator mode, ask for three independent jobs, and confirm the
  chat continues while threads run. Answer a thread question, approve a
  thread command, continue a finished thread, and check background
  notifications. Record the results in the bead.
- [ ] 10.2 Run the full gates, update goldens only for intended diffs,
  release the next `-you.<n>` per `docs/FORK.md`, and update
  `docs/FORK_HANDOVER.md` with the feature and its gateway requirement.

## Workflow follow-up

- Archive this change with `/opsx:archive` after 10.2 and sync the three
  new specs into `openspec/specs/`.
