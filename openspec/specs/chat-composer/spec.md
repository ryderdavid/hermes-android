# chat-composer Specification

## Purpose
The message composer at the bottom of a chat: one rounded input with dictation, attach outside the field, and a Send/Stop button, behaving the same as before the redesign.
## Requirements
### Requirement: Single rounded input container
The composer SHALL present the text input as one fully rounded container filled with a surface-container role, with no outline in its resting state, a minimum height of 48 dp, and growth to a bounded maximum as text wraps.

#### Scenario: Empty composer
- **WHEN** a chat opens with an empty draft
- **THEN** the input renders as a single rounded 48 dp pill with placeholder text and no border

#### Scenario: Long draft
- **WHEN** the draft wraps past one line
- **THEN** the container grows up to its maximum height and then scrolls internally, keeping its corner radius

### Requirement: Inline secondary actions
Attach SHALL sit inside the container at its leading edge and dictation (mic) SHALL sit inside at its trailing edge, both as standard icon buttons using on-surface-variant color.

#### Scenario: Action placement
- **WHEN** the composer is idle
- **THEN** attach and mic icons appear inside the rounded field, not as separate filled circles beside it

### Requirement: Send button sizing and state
A single primary action SHALL sit outside the container at the trailing edge, at most 48 dp and never taller than the container. It SHALL show Send when the draft is non-empty, Stop while a turn is running, and SHALL be disabled-styled when nothing can be sent.

#### Scenario: Typing enables send
- **WHEN** the user types the first character
- **THEN** the trailing button becomes an enabled primary-colored Send button aligned to the bottom of the field

#### Scenario: Turn in progress
- **WHEN** the agent is streaming a response
- **THEN** the trailing button shows Stop and stopping the turn works as before

### Requirement: Steer-send while a turn runs
While a turn is running and the draft has text or attachments, an additional compact send button (key `composer-steer-send`) SHALL appear just left of Stop; tapping it sends the draft to the gateway mid-turn, where `busy_input_mode` decides whether it interrupts, queues, or steers. With an empty draft, only Stop SHALL appear.

#### Scenario: Steering a running turn
- **WHEN** the agent is streaming and the draft is non-empty
- **THEN** a steer send button appears next to Stop, and tapping it submits the draft without stopping the turn

### Requirement: No turn-status bar above the composer
While sending or streaming, work-in-progress SHALL be represented by the timeline activity rows and the chat app bar spinner (which carries the gateway's live turn-status text, ellipsized); the composer SHALL NOT grow a status bar above the input row.

#### Scenario: Status lives in the app bar
- **WHEN** a turn is running
- **THEN** the composer height is unchanged and the app bar shows only the spinner (live status text rides its semantics label)

### Requirement: Secondary controls stay compact
Model selection and the spoken-reply toggle SHALL be presented as compact chips or an overflow above or within the composer, not as additional 48 dp circular buttons in the input row.

#### Scenario: Model chip
- **WHEN** the user taps the model chip above the field
- **THEN** the existing per-chat model and thinking-effort picker opens

### Requirement: Composer behaviour parity
The redesign SHALL preserve existing composer behaviour: Enter-to-send setting, multi-attachment drafts with reorder/remove/retry, voice dictation, durable per-chat drafts, and keyboard inset handling.

#### Scenario: Attachments still work
- **WHEN** the user attaches three images
- **THEN** the attachment tray appears above the field with reorder, remove and retry, and sending uploads them in order as before

### Requirement: Secondary controls outside the input row
The model choice SHALL be reachable from the chat app bar subtitle and spoken replies from the chat overflow menu; the composer SHALL contain only attach, the text field with dictation, and Send/Stop — plus the steer-send button while a turn runs with a non-empty draft.

#### Scenario: Changing model
- **WHEN** the user taps the model subtitle under the chat title
- **THEN** the existing per-chat model picker opens

### Requirement: Attach outside the field
Attach SHALL be a 48dp tonal circular button at the leading edge outside the rounded field.

#### Scenario: Idle composer
- **WHEN** a chat opens
- **THEN** the row shows the attach circle, the rounded field with the dictation icon inside, and the Send button

