# Proposal: Topic icons for chats

## Why

Every unassigned chat is drawn as the same rounded diamond holding the first
letter of its title, so a list of chats looks the same from row to row. Ryder
asked for an option where a model picks an icon that fits each chat's topic,
inside a mix of Material 3 Expressive shapes.

Mockup: https://claude.ai/artifact/NixjUP4i9TzuvG2LYvNwyZ

## What changes

- A **Chat icons** setting on the Appearance page, with three choices:
  - **Letter** (default): today's look.
  - **On device**: an icon matched to the title from a fixed set of about 190
    Material icons, with no network call.
  - **By Hermes**: the gateway's model picks from the same set. Until it
    answers, the chat shows the on-device match.
- When icons are on, each chat gets one of nine expressive shapes and one of
  three tones, derived from the chat id so a chat never changes. Turning off
  **Mixed shapes** puts every chat on the cookie shape.
- Hermes labels chats in batches, inside one hidden chat a day named
  `hermes-android-chat-icons-<date>`. Only titles are sent. The app hides
  those chats from every list.
- Labels are stored on the device, per connection. Renaming a chat asks
  again, and **Relabel all chats** clears Hermes's labels.

## Impact

- New: `lib/core/chat_icons/` (vocabulary, matcher, preferences, store,
  labeller, `ChatMark` widget).
- Changed: the expressive shapes, the session-list filters, Home, Chats, the
  chat app bar, the Appearance page, and l10n.
