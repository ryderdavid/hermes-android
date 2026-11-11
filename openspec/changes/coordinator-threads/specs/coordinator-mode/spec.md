# Spec Delta

## Purpose

The per-chat coordinator setting. With it on, the main agent keeps the
conversation with the user and hands longer work to background threads.
This spec covers how the setting is turned on, stored, sent to the gateway
and shown.

## ADDED Requirements

### Requirement: Per-chat coordinator toggle
The chat actions menu SHALL offer a Coordinator mode toggle with a one-line
explanation. The setting SHALL be stored per chat, SHALL survive app
restarts, and SHALL be included in configuration backup and restore. New
chats SHALL start with the mode off unless the user has turned on the
"new chats use coordinator mode" default.

#### Scenario: Turning it on
- **WHEN** the user turns on Coordinator mode in a chat
- **THEN** the menu item shows as checked, the app bar shows a Coordinator label under the chat title, and the next prompt in that chat is sent in coordinator mode

#### Scenario: Persisted across restarts
- **WHEN** the app is restarted and the user reopens a chat that had Coordinator mode on
- **THEN** the mode is still on

#### Scenario: Default for new chats
- **WHEN** the user has turned on the default and starts a new chat
- **THEN** the new chat starts in coordinator mode

### Requirement: Coordinator mode reaches the gateway
When coordinator mode is on, each prompt from the chat SHALL tell the
gateway session to run in coordinator mode. In that mode, the gateway
SHALL:
- give the main agent instructions to answer the user directly;
- send multi-step or long-running work to background threads;
- keep the user informed of what each thread is doing.

Turning the mode off SHALL return later prompts to normal behaviour. It
SHALL NOT stop threads that are already running.

#### Scenario: Long request in coordinator mode
- **WHEN** coordinator mode is on and the user asks for three independent pieces of work
- **THEN** the main agent replies in the same turn, the work runs as background threads, and the user can keep chatting while it does

#### Scenario: Turning it off mid-work
- **WHEN** the user turns coordinator mode off while two threads are running
- **THEN** both threads keep running and still report back, and the next prompt is handled in normal mode

### Requirement: Unsupported gateways
If the connected gateway does not advertise coordinator mode, the toggle
SHALL be shown disabled with an explanation that the gateway needs
updating. The app SHALL NOT imitate coordinator mode by changing the user's
prompt text.

#### Scenario: Older gateway
- **WHEN** the chat's gateway lacks the coordinator-mode capability
- **THEN** the toggle is disabled, its subtitle says the gateway must be updated, and prompts are sent unchanged
