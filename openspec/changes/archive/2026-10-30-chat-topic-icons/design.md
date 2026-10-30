# Design: Topic icons for chats

## D1. Hermes chooses from a vocabulary; it does not draw

A model choosing an icon name from a fixed list is reliable, cheap and renders
crisply in every theme. A model drawing SVG paths is none of those. The
vocabulary is about 190 Material icons that exist in Flutter's `Icons` (rounded
variants), each with keywords for the on-device matcher. Any name Hermes
returns that is not in the list is ignored.

## D2. One hidden chat a day

The gateway has no completion endpoint without side effects: every
`/v1/chat/completions` call is an agent turn that is saved as a session.
Labelling therefore reuses one client-chosen session id a day,
`hermes-android-chat-icons-YYYYMMDD`. This keeps history small enough to avoid
compression, and the prefix is enough to hide it. The session-list parsers drop
any session whose id or lineage root starts with the prefix.

## D3. Batching

Titles are queued as rows render. After a two-second quiet period, up to 40
titles go out in one request. Only one batch is in flight per connection, and
a failed batch backs off for five minutes. The system prompt asks for JSON
only, with no tools and no memory writes.

## D4. Storage

The store is per connection in SharedPreferences: session id →
`{icon, title hash, source}`. A label whose title hash no longer matches is
stale. In **By Hermes** mode a stale label is requeued; in the meantime the
on-device match is shown.

## D5. Shape and tone

The shape and tone come from a stable hash of the session id, taken from the
nine `ExpressiveShape.chatMarks` and the three container tones. The polar
shape formula gains a rotation so the 4-lobed shapes sit upright.
