# Spec Delta

## Purpose

Defines the look and behaviour of the chat message input bar so it reads like the Google Messages composer: one rounded field that owns its actions, with no control larger than the field itself.

## ADDED Requirements

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
