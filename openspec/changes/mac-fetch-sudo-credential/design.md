# Design

## Context

`store-agent-pseudo-password` (change in this repo, shipped in v2.1.31-you.1) stores the SUDO password Keystore-protected per connection and auto-answers `sudo.request` server requests during phone-driven chats. Unattended Mac-side agents (CLI/TUI on the Mac, no phone chat) cannot reach that credential. The Desktop gateway already has a server-request mechanism (`sudo`/`secret`/`clarify` methods with `request_id`, answered via `respond`) — the natural extension is a new method the Mac initiates when it needs the credential itself. See proposal.md for motivation.

## Goals / Non-Goals

**Goals:**
- Paired Mac can fetch the stored SUDO password on demand, only when the user explicitly enabled fetch for that connection, with a full audit trail on the phone.
- Reuse the existing server-request plumbing; no new listening ports on the phone, no reverse tunnels.

**Non-Goals:**
- No standing/pull-forever credential: every fetch is a discrete request/response, audited.
- No Mac-side implementation in this repo (cross-repo; see Impact in proposal.md).
- No changes to `sudo.request` auto-answer behavior.

## Decisions

1. **New server-request method `agent_credential.request` answered by the phone.** The phone is the gateway *client*; the Mac is the server. The Mac sends the request on the paired control WebSocket; the app answers via the existing `_serverRequests`/`respond({'value': ...})` path. Alternative: phone exposes an HTTP endpoint the Mac polls — rejected (new attack surface on the phone, needs inbound connectivity; the gateway socket already exists and is authenticated).
2. **Separate per-connection fetch toggle, default off**, stored as a plain SharedPreferences bool keyed by connection identity (`agent_credential_fetch|<identity>`), biometric/PIN gated via the existing `BiometricGate`. Alternative: reuse the auto-answer toggle — rejected; auto-answer is about answering sudo prompts, fetch is a stronger grant (the Mac gets the raw value), so it must be separately consented.
3. **Audit entries gain a `kind` field** (`auto_answer` | `fetch`). Existing entries read as `auto_answer` for backward compatibility. Same storage (`agent_sudo_audit`), same 200-entry cap, never the value.
4. **Refusal is explicit and value-free.** When fetch is disabled or no credential is stored, respond `{'error': 'fetch_disabled'}` (or equivalent) — never an empty string that could be mistaken for a password, and never the value.
5. **Fetch responses are mirrored to a notification when backgrounded**, same as auto-answers, with a fixed notice string containing no secret.
6. **Transport unchanged:** value travels only inside the gateway WebSocket response to the paired connection — same channel class as today's manual sudo answers.

## Risks / Trade-offs

- **[Risk] The Mac now holds the raw admin password after a fetch.** → Fetch is a deliberate, audited, per-connection grant the user can revoke instantly (toggle off or clear). Mac-side must treat the fetched value like `SUDO_PASSWORD` (never logged). Documented in the consumer contract. Alternative considered: Mac requests a one-time sudo token instead of the password — rejected because macOS sudo has no token concept; the password is what sudo needs.
- **[Risk] Malicious/compromised gateway peer could request fetches repeatedly.** → Each fetch is audited on the phone and notification-mirrored; the user sees the trail and can revoke. Pairing is over Tailscale/authenticated gateway only.
- **[Risk] Phone offline when the Mac needs sudo.** → Fetch simply fails closed (refusal/timeout); Mac falls back to existing local mechanisms. No degradation of current behavior.
- **[Trade-off] The phone must be connected to the gateway for fetch to work.** → Accepted; unattended Mac use assumes the phone is reachable on the tailnet, which is the deployment Ryder uses.

## Migration Plan

Additive; both toggles default off. Existing stored passwords and audit entries keep working; old audit entries default to kind `auto_answer`. Rollback: disable fetch toggle / clear password; no protocol changes to undo.

## Open Questions

- Exact JSON-RPC method name (`agent_credential.request`) must match the Mac-side Hermes implementation; coordinate the cross-repo change to use the same string. Assumed as specified here.
