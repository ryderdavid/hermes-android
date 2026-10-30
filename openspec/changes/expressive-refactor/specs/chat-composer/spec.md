# Spec Delta

## ADDED Requirements

### Requirement: Secondary controls outside the input row
The model choice SHALL be reachable from the chat app bar subtitle and spoken replies from the chat overflow menu; the composer SHALL contain only attach, the text field with dictation, and Send/Stop.

#### Scenario: Changing model
- **WHEN** the user taps the model subtitle under the chat title
- **THEN** the existing per-chat model picker opens

### Requirement: Attach outside the field
Attach SHALL be a 48dp tonal circular button at the leading edge outside the rounded field.

#### Scenario: Idle composer
- **WHEN** a chat opens
- **THEN** the row shows the attach circle, the rounded field with the dictation icon inside, and the Send button
