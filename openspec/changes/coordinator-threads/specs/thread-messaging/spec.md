# Spec Delta

## Purpose

The message contract between a parent chat and its threads. It covers
interim updates and questions a running thread sends to its parent, replies
to those questions, and follow-ups to a finished thread. It includes both
the gateway behaviour and how the app shows it.

## ADDED Requirements

### Requirement: Thread updates to the parent
A running thread SHALL be able to send its parent an interim update without
finishing. The gateway SHALL deliver each update to the parent session
exactly once, including after a gateway restart. If the parent is idle, the
update SHALL be delivered as a new parent turn. If the parent is mid-turn,
it SHALL be held until that turn ends and then delivered. It SHALL NOT be
inserted into the reply in progress. Updates SHALL be rate-limited per
thread.

#### Scenario: Update while the parent is idle
- **WHEN** a thread sends "2 of 5 jobs fail on Android API 35" and the parent session is idle
- **THEN** the parent receives it as a new turn, and the app shows it as an update card naming the thread, with Open thread

#### Scenario: Update while the parent is mid-turn
- **WHEN** a thread sends an update while the coordinator is answering the user
- **THEN** the update is not shown inside the in-progress reply; it is delivered as a new parent turn once that reply ends, and the app shows the update card there

#### Scenario: Restart during delivery
- **WHEN** the gateway restarts after an update was queued but before it was delivered
- **THEN** the update is delivered once after restart and is not duplicated

#### Scenario: Chatty thread
- **WHEN** a thread sends more updates than the per-thread limit allows within the window
- **THEN** the excess updates are merged into the next allowed delivery instead of each starting a parent turn

### Requirement: Thread questions
A running thread SHALL be able to ask its parent a question and wait for
the answer without finishing. The app SHALL show the question as an
emphasised card naming the thread, with Reply, Let coordinator decide, and
Open thread. While the question is unanswered, the thread SHALL show the
"needs you" state.

#### Scenario: User replies
- **WHEN** the licences thread asks whether to drop two AGPL packages and the user taps Reply and answers "Flag them for legal"
- **THEN** the answer is delivered to that thread only, the thread resumes, and the card shows the answer and who gave it

#### Scenario: Coordinator decides
- **WHEN** the user taps Let coordinator decide
- **THEN** the coordinator agent is asked to answer, its answer is delivered to the thread, and the card records that the coordinator answered

### Requirement: Unanswered questions expire
A question left unanswered past the gateway's wait limit SHALL resume the
thread with an explicit "no answer" result.

#### Scenario: Nobody answers
- **WHEN** a question is not answered within the gateway's wait limit
- **THEN** the thread resumes with a no-answer result, the card is marked expired, and the thread's state leaves "needs you"

### Requirement: Continue a finished thread
The user or the coordinator SHALL be able to send a follow-up to a finished
thread. The thread SHALL run again with its own earlier history. When it
finishes, it SHALL report to the parent the same way as its first run. A
follow-up SHALL count against the background slot limit like a new
thread.

#### Scenario: Continue from the report card
- **WHEN** the user taps Continue on the release-notes report card and asks for a shorter summary
- **THEN** the same thread runs again with its earlier history, the roster shows it as running, and a new report card appears when it finishes

#### Scenario: Slots full
- **WHEN** all background slots are in use and the user continues a finished thread
- **THEN** the follow-up is queued, the thread shows as queued, and it starts when a slot frees

### Requirement: Capability advertisement
The gateway SHALL advertise thread updates, thread questions, continuable
threads and coordinator mode as separate capabilities. The app SHALL enable
each matching control only when its capability is present.

#### Scenario: Partial support
- **WHEN** a gateway supports thread updates but not continuable threads
- **THEN** update cards render, and the Continue action on report cards is hidden
