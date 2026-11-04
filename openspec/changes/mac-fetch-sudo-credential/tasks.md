# Tasks

## 1. Fetch permission and storage

- [x] 1.1 Add `agent_credential_fetch|<connectionIdentity>` bool preference (default false) to `AgentCredentialService`: `isFetchEnabled` / `setFetchEnabled`. Verify with unit tests (default false, per-connection isolation).
- [x] 1.2 Extend `AgentSudoAuditEntry` with a `kind` field (`auto_answer` default for old entries, `fetch` for fetches); migrate reading of existing entries. Verify with unit tests (old JSON without kind reads as auto_answer; new kinds round-trip; cap still enforced).

## 2. Gateway request handling

- [x] 2.1 Handle server-request method `agent_credential.request` in the Desktop gateway client path: when fetch enabled and credential stored, respond once with `{'value': <stored>}`; otherwise respond with a value-free refusal. Never log or display the value. Verify with unit tests using a fake WsClient (enabled→value sent once + audit kind fetch; disabled→refusal, no value; no credential→refusal).
- [x] 2.2 Record audit entry (kind `fetch`, connection label, request id) and mirror a fixed-string notification when backgrounded. Verify payload contains no credential material.
- [x] 2.3 Ensure clearing the password or disabling the toggle takes effect immediately for in-flight and future requests. Verify with unit tests.

## 3. Settings UI and l10n

- [x] 3.1 Add the "Allow Mac to fetch SUDO password" toggle to `AgentCredentialCard`, biometric/PIN gated via `BiometricGate`, with a warning subtitle that the paired Mac will receive the actual password on request. Verify with widget tests (toggle on→gate→pref set; gate refused→pref unchanged; toggle off→immediate).
- [x] 3.2 Show audit entry kind in the audit list; add l10n keys to app_en.arb (other locales fall back). Verify with `flutter analyze` and widget test.

## 4. Verify and deliver

- [x] 4.1 Run `flutter analyze` and full `flutter test` green, including the new tests. Verify with both outputs.
- [ ] 4.2 Cross-repo QA: with the Mac-side change implemented, pair the phone, enable fetch, and from the Mac run an unattended sudo command end-to-end; confirm the phone audit shows a `fetch` entry and the Mac command succeeded. Verify on-device.
- [x] 4.3 Release as the next `-you.N` build with signed split APKs, GitHub release, Taildrop to the phone (same pipeline as v2.1.31-you.1).

## Workflow follow-up

- Coordinate the consumer contract (`agent_credential.request` method name and response shape) with the Hermes desktop/agent repo change before implementing 2.1.
- After implementation: apply review, archive with `/openspec-archive-change` once merged.
