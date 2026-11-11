# Spec Delta

## Purpose

How tool calls and reasoning appear in a chat: as one-line rows in time
order with the agent's messages, folded away once a turn finishes, with
detail available on tap. It also defines what the message-metadata setting
changes.

## ADDED Requirements

### Requirement: One-line activity rows
Each tool call SHALL appear in the chat as a single row showing an icon for
the kind of tool and the call's plain-language summary, on one line,
truncated if too long. A running call SHALL show a progress indicator and
normal text colour. A finished call SHALL be visually muted. A failed call
SHALL use the error colour and state that it failed. Rows SHALL NOT be
wrapped in a card and SHALL NOT expand in place.

#### Scenario: A tool starts
- **WHEN** the agent starts a tool call during a turn
- **THEN** one row is added for it with a progress indicator, and no other item in the chat changes size

#### Scenario: A tool finishes
- **WHEN** a running tool call completes
- **THEN** its row keeps its position and height, loses the progress indicator, and becomes muted

#### Scenario: A tool fails
- **WHEN** a tool call fails
- **THEN** its row uses the error colour and its label states that the call failed

#### Scenario: Screen reader
- **WHEN** a screen reader focuses a row
- **THEN** it announces the tool kind, the summary and the state (running, completed or failed), and that the row can be activated for details

### Requirement: Time order with messages
Activity rows and the agent's messages SHALL appear in the order they
happened, both while a turn is running and when a chat is loaded from
history. A tool call made after an interim message SHALL appear below that
message, and one made before it SHALL appear above it.

#### Scenario: Live turn with interim text
- **WHEN** the agent runs two tools, writes an interim message, then runs a third tool
- **THEN** the chat shows two rows, then the message, then the third row

#### Scenario: Same order after reload
- **WHEN** that chat is closed and reopened after the turn finished
- **THEN** unfolding the turn shows the same sequence

### Requirement: New activity does not move what the user is reading
Adding or updating an activity row SHALL NOT change the height of any item
above it. While the user has scrolled away from the end of the chat, new
rows SHALL NOT move the content on screen.

#### Scenario: Reading earlier text during a long turn
- **WHEN** the user has scrolled up to read an earlier message and the agent runs five more tools
- **THEN** the text on screen stays where it is, and the usual jump-to-latest control indicates new activity

### Requirement: Reasoning as a row
Reasoning SHALL appear as an activity row in time order, labelled with the
first line of the reasoning text, or a generic label when the text has no
usable first line. It SHALL follow the same folding rules as tool rows.

#### Scenario: Reasoning with a headline
- **WHEN** the agent's reasoning begins with "Checking the service binding"
- **THEN** a reasoning row shows that text on one line with the reasoning icon

#### Scenario: Reading the reasoning
- **WHEN** the user taps a reasoning row
- **THEN** a sheet opens with the full reasoning text, which can be selected and copied

### Requirement: Finished turns fold automatically
When a turn finishes with a final answer, everything the agent did before
that answer (activity rows and interim messages) SHALL fold into a single
line stating how long the turn worked. The final answer SHALL stay visible
below it. Turns loaded from history SHALL start folded. A turn with no
tool calls or reasoning SHALL show no fold line. A turn that ends without a
final answer SHALL stay unfolded.

#### Scenario: Turn completes
- **WHEN** a turn with six tool calls and one interim message finishes with a final answer
- **THEN** the rows and interim message are replaced by one "Worked for…" line, and the final answer remains in view

#### Scenario: Turn with failures
- **WHEN** a folded turn contains a failed tool call
- **THEN** the fold line indicates that something failed, using the error colour

#### Scenario: Duration unknown
- **WHEN** the turn's start or end time is not known
- **THEN** the fold line states the number of steps instead of a duration

#### Scenario: Plain reply
- **WHEN** the agent answers without using tools or reasoning
- **THEN** no fold line is shown

#### Scenario: Interrupted turn
- **WHEN** a turn is stopped before the agent writes a final answer
- **THEN** its rows and interim messages stay visible

### Requirement: Unfolding a turn
Tapping the fold line SHALL show the turn's full sequence in time order,
and tapping it again SHALL fold it. The user's choice for a turn SHALL
persist while the chat stays open, including when the turn scrolls out of
view and when the chat's history is refreshed.

#### Scenario: Unfold and scroll away
- **WHEN** the user unfolds a turn, scrolls far enough that it leaves the screen, and scrolls back
- **THEN** the turn is still unfolded

#### Scenario: Refresh keeps the choice
- **WHEN** the chat's history reloads while a turn is unfolded
- **THEN** the turn stays unfolded

### Requirement: Grouping in unfolded finished turns
In an unfolded finished turn, consecutive successful calls of the same kind
of tool with no message between them SHALL be shown as one group row
stating the kind and the count. A failed call SHALL always have its own
row. Rows in a running turn SHALL NOT be grouped.

#### Scenario: Three commands in a row
- **WHEN** a finished turn ran three terminal commands back to back
- **THEN** unfolding it shows one row "Ran 3 commands"

#### Scenario: Failure inside a run
- **WHEN** the second of three back-to-back commands failed
- **THEN** the failed command has its own error-coloured row and is not hidden in a group

### Requirement: Detail sheet
Tapping an activity row SHALL open a bottom sheet showing the kind of tool,
its state and its summary, plus the duration, time, command or arguments,
and a length-limited output excerpt when each is known. Commands and output
SHALL be copyable. Information that is not available SHALL be omitted.

#### Scenario: Single command
- **WHEN** the user taps a completed terminal row
- **THEN** a sheet shows that it completed, how long it took, its summary, the command in a copyable code block, and an output excerpt

#### Scenario: Older call without stored detail
- **WHEN** the user taps a row from history whose command and output are not available
- **THEN** the sheet shows the summary, state and time only, with no empty sections

#### Scenario: Chat state preserved
- **WHEN** the user opens and closes a detail sheet with an unsent draft in the composer
- **THEN** the draft and the chat's scroll position are unchanged

### Requirement: Group detail sheet
Tapping a group row SHALL open one sheet listing each call in the group
with its summary and command.

#### Scenario: Group of commands
- **WHEN** the user taps "Ran 3 commands"
- **THEN** a sheet titled for that kind of tool lists the three calls, each with its summary and command

### Requirement: Message-metadata setting
The setting formerly called Verbose Mode SHALL only control whether each
message shows its stored metadata. It SHALL NOT change how activity rows,
reasoning or folding behave. It SHALL be named and described as a debugging
aid for message metadata and SHALL be listed in the About group of
Settings. A value saved before this change, including one restored from a
backup, SHALL keep its effect.

#### Scenario: Setting on
- **WHEN** the setting is on
- **THEN** messages show their metadata lines, and finished turns still fold exactly as when it is off

#### Scenario: Existing preference
- **WHEN** a user who had Verbose Mode on updates the app
- **THEN** the renamed setting is on and messages still show their metadata
