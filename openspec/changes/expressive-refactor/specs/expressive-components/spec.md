# Spec Delta

## ADDED Requirements

### Requirement: Expressive shape marks
Projects, connections and agent avatars SHALL be drawn as Material 3 Expressive shapes (cookie, clover, sunny, burst, flower, soft) filled with a container role, and a given project SHALL always get the same shape and role.

#### Scenario: Same project, same mark
- **WHEN** a chat in project "Home lab" appears on Home, in Chats and in the chat app bar
- **THEN** all three show the same shape and colour role

### Requirement: Segmented grouped lists
Lists of settings, chats and panes SHALL render as segmented groups: tiles separated by 2dp, outer corners 24dp, inner corners 4dp, on a surface-container role, each row at least 56dp tall.

#### Scenario: Three rows
- **WHEN** a group has three rows
- **THEN** the first has 24dp top corners, the last 24dp bottom corners, the middle 4dp corners, with 2dp gaps

### Requirement: Spring motion
Shape and position changes on primary controls (Send/Stop, connected-button selection, theme changes) SHALL animate with the Expressive spring tokens rather than fixed-duration easing.

#### Scenario: Send becomes Stop
- **WHEN** a turn starts
- **THEN** the send button's corners spring from fully round to 14dp as its icon changes to Stop

### Requirement: Expressive loading and progress
Work in progress SHALL use the shape loading indicator (a rotating, pulsing expressive shape on a container) and running jobs SHALL show wavy progress where progress is known.

#### Scenario: Turn running
- **WHEN** Hermes is working on a turn
- **THEN** the turn status shows the shape loading indicator, not a circular spinner

### Requirement: Connected button groups and split buttons
Mutually exclusive filters and modes SHALL use a connected button group whose selected button becomes fully rounded; a primary action with alternatives SHALL use a split button.

#### Scenario: Chat filters
- **WHEN** the user selects "Unassigned" in Chats
- **THEN** that button becomes fully rounded and filled, the others keep 8dp inner corners, and the list filters
