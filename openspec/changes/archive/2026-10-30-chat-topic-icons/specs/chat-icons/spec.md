# Spec Delta

## ADDED Requirements

### Requirement: Chat icon modes
The Appearance page SHALL offer a Chat icons choice of Letter, On device or By Hermes. Letter SHALL be the default and SHALL draw chats as before.

#### Scenario: Switching to On device
- **WHEN** the user chooses On device
- **THEN** each chat whose title matches a topic shows that topic's icon inside its shape, with no network request

### Requirement: Stable shapes per chat
With icons on and Mixed shapes enabled, each chat SHALL be drawn in one of nine expressive shapes and one of three tones derived from its id, the same on every screen and across restarts.

#### Scenario: Same chat, same shape
- **WHEN** a chat appears on Home, in Chats and in its app bar
- **THEN** all three show the same shape, tone and icon

### Requirement: Hermes picks icons from a vocabulary
In By Hermes mode the app SHALL send chat titles, and nothing else, in batches to a hidden daily session, and SHALL accept only icon names from its vocabulary. Until a label arrives, the on-device match SHALL be shown.

#### Scenario: Unknown icon name
- **WHEN** Hermes answers with a name not in the vocabulary
- **THEN** the chat keeps its on-device icon

### Requirement: Hidden labelling sessions
Sessions whose id or lineage root starts with `hermes-android-chat-icons-` SHALL NOT appear in any session list, archive or search result in the app.

#### Scenario: Labelling chat listed by the gateway
- **WHEN** the gateway lists the hidden labelling session
- **THEN** Home, Chats and search do not show it
