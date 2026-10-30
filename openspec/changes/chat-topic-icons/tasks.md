# Tasks

## 1. Model

- [x] 1.1 More expressive shapes (6- and 4-sided cookie, 8-leaf clover, pentagon) with rotation, plus `ExpressiveShape.chatMarks`.
- [x] 1.2 Topic vocabulary (about 190 Material icons with keywords) and an on-device title matcher; unit tests.
- [x] 1.3 Chat icon preferences (mode, mixed shapes) and a per-connection label store; unit tests.

## 2. Hermes labelling

- [x] 2.1 `ChatIconLabeller`: batched, debounced requests to the hidden daily session; JSON parsing restricted to the vocabulary; backoff; tests with a fake gateway client.
- [x] 2.2 Hide `hermes-android-chat-icons-*` sessions from session lists, archived lists and search.

## 3. UI

- [x] 3.1 `ChatMark` widget and `ChatIconScope`; use it on Home, Chats and the chat app bar.
- [x] 3.2 Appearance → Chat icons group: samples, Letter / On device / By Hermes, Mixed shapes, Relabel all chats, privacy note; l10n in all locales.

## 4. Verify and deliver

- [x] 4.1 Full suite, analyze, colour lint, goldens for the chat icons, accessibility guidelines.
- [ ] 4.2 Release 2.1.30-you.4, signed split APKs, GitHub release, APK to the phone over Tailscale.
