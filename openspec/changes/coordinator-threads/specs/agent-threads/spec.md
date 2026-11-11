# Spec Delta

## Purpose

How a chat shows, opens, follows, steers and stops the threads (delegated
subagents) its gateway session started, and how their start, completion and
approvals appear in the parent chat.

## ADDED Requirements

### Requirement: Threads roster in the chat
A chat with at least one thread SHALL show a roster under the context
header. Each entry shows the thread's goal and state: running, needs you,
done or failed. Entries that need the user SHALL come first and SHALL be
visually emphasised. A chat with no threads SHALL NOT show the roster.

#### Scenario: Roster appears when a thread starts
- **WHEN** the gateway reports a new thread for the open chat's session
- **THEN** the roster appears with an entry for that thread in the running state, without reloading the chat

#### Scenario: Waiting thread is emphasised
- **WHEN** a thread has an unanswered question for the user
- **THEN** its roster entry is listed first, shows the "needs you" state, and uses the emphasised container colour

#### Scenario: Chat without threads
- **WHEN** a chat's session has never started a thread
- **THEN** no roster is shown and the chat layout is unchanged from today

### Requirement: Threads sheet
From the roster, the user SHALL be able to open a sheet that lists every
thread in the chat. The sheet shows active threads, the number of
background slots in use out of the gateway's limit, and earlier finished
threads. Its actions are: stop one thread, stop all threads, and pause new
threads. Pausing is gateway-wide, and the sheet SHALL say that it affects
every chat on that gateway.

#### Scenario: Slot usage is visible
- **WHEN** two threads are running and the gateway's background limit is three
- **THEN** the sheet states that 2 of 3 slots are in use

#### Scenario: Pause is gateway-wide
- **WHEN** the user chooses Pause new threads
- **THEN** the control states that it pauses new threads for every chat on this gateway, and the roster in every open chat shows that threads are paused

#### Scenario: Stop all
- **WHEN** the user chooses Stop all and confirms
- **THEN** every running thread in this chat is interrupted, and each entry moves to a stopped or failed state once the gateway confirms it

### Requirement: Thread view
Tapping a thread SHALL open a thread view that shows:
- the task text the coordinator gave the thread;
- the thread's state, tool count, elapsed time and model;
- the thread's tool activity and text, in the same card styles the main
  chat uses.

While the thread runs, the view SHALL update live. After the thread
finishes, it SHALL show the stored transcript. Opening or closing the view
SHALL NOT change the parent chat's draft, scroll position or composer
state.

#### Scenario: Live thread
- **WHEN** the user opens a running thread
- **THEN** new tool calls and text from that thread appear in the view as they happen, with a live indicator

#### Scenario: Finished thread
- **WHEN** the user opens a thread that has finished
- **THEN** the view shows the stored transcript, marks the thread done or failed, and shows no live indicator

#### Scenario: History partly unavailable
- **WHEN** part of a finished thread's stored history cannot be loaded
- **THEN** the view shows what it could load and labels the missing part as unavailable instead of failing outright

#### Scenario: Parent state preserved
- **WHEN** the user has an unsent draft in the parent chat, opens a thread, and returns
- **THEN** the draft text and the parent scroll position are unchanged

### Requirement: Steer and stop a running thread
The thread view of a running thread SHALL offer a steer input and a Stop
control. Sent steer text SHALL be delivered to that thread only. The view
SHALL show whether the thread accepted the text or finished before it could
apply it. Stop SHALL interrupt that thread only.

#### Scenario: Steer accepted
- **WHEN** the user sends "Skip dev-only dependencies" to a running thread
- **THEN** the thread receives it at its next step, and the view records the steer as acknowledged

#### Scenario: Steer races with completion
- **WHEN** a thread finishes before steer text reaches it
- **THEN** the view states that the steer did not land, and keeps the text so the user can send it as a follow-up

#### Scenario: Steering unsupported
- **WHEN** the gateway reports that a thread does not accept steering
- **THEN** the steer input is disabled with an explanation, and Stop remains available

### Requirement: Thread cards in the parent chat
When the coordinator's turn starts threads, the parent chat SHALL show one
card listing those threads, with their live state, that opens each one.
When a thread finishes, its result SHALL appear as a report card with:
- the thread's goal and outcome;
- tool count and duration;
- the summary;
- actions to open the thread and to continue it.

The report card replaces the raw task-source text in the transcript.

#### Scenario: Threads started
- **WHEN** a single parent turn starts three threads
- **THEN** one card lists all three, and each row's state updates as the threads progress

#### Scenario: Thread report
- **WHEN** a background thread finishes and the gateway delivers its result as a new parent turn
- **THEN** that turn shows a report card instead of the raw result block, and the coordinator's reply that follows it shows as a normal message

#### Scenario: Old gateway
- **WHEN** the gateway does not advertise thread support
- **THEN** delegated work is still shown as a read-only list of tasks with their state, as before

### Requirement: Approvals raised by threads
An approval, secret or sudo request raised by a thread SHALL be presented in
the parent chat's screen and SHALL name the thread that raised it. Answering
it SHALL answer only that request.

#### Scenario: Thread asks for approval
- **WHEN** the "Check CI matrix" thread needs approval to run a command
- **THEN** the approval sheet opens over the parent chat, names "Check CI matrix", and Allow or Deny goes back to that thread's request

#### Scenario: Thread approval while the user is in another chat
- **WHEN** a thread raises an approval while its parent chat is not open
- **THEN** a notification names the chat and the thread, and opening it shows the approval in the parent chat

### Requirement: Thread notifications
When a thread finishes, fails, or asks the user a question while its
parent chat is not on screen, the app SHALL post a notification. Thread
notifications SHALL follow the same notification preferences and privacy
setting as turn-completion notifications.

#### Scenario: Thread finishes in the background
- **WHEN** a thread finishes while the app is in the background and turn notifications are on
- **THEN** a notification shows the thread's goal and outcome, and tapping it opens the parent chat at the report card

#### Scenario: Private notifications
- **WHEN** notification privacy hides message content
- **THEN** thread notifications show only that a thread finished or needs attention, without its goal or summary
