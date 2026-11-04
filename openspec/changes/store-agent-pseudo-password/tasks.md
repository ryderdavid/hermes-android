# Tasks

## 1. Credential store service

- [x] 1.1 Create `lib/core/services/agent_credential_service.dart`: save/load/has/clear for the pseudo-password via `FlutterSecureCredentialStore` with `storageNamespace: 'hermes_android_agent_credentials'`, `resetOnError: true`, `migrateWithBackup: false`; keys prefixed by connection id. Verify with unit tests using an in-memory fake `CredentialStore` (save→load round-trip, clear→absent, per-connection isolation).
- [x] 1.2 Add a fail-closed read path: on Keystore error the service reports "absent" and never returns a partial/plaintext value. Verify with a fake store that throws on read.
- [x] 1.3 Add audit store (`agent_credential_audit.dart`): append `{timestamp, connectionId, connectionLabel, requestId}`, cap 200 entries, SharedPreferences JSON; never stores the value. Verify with unit tests.

## 2. Preferences and gating

- [x] 2.1 Add per-connection `auto_answer_sudo` boolean preference (SharedPreferences, default false) with provider. Verify with unit tests (default false, per-connection independence).
- [x] 2.2 Add `local_auth` to pubspec.yaml (`flutter pub get`) and a biometric/PIN gate helper that refuses when neither is enrolled. Verify with unit tests around a fake authenticator (enrolled→allowed, none→refused, fallback to re-entering the password).

## 3. Auto-answer flow

- [x] 3.1 In the `sudo.request` handling path (`chat_screen.dart` / `gateway_turn_application_controller.dart`), before queueing the dialog: if the connection has auto-answer on and a credential is stored, call the existing `respondToSudo` with the stored value, append an audit entry, and skip the dialog. Verify with unit tests using a fake gateway client (auto-answer on → responded without dialog; off → dialog queued).
- [x] 3.2 On rejection/expire of an auto-answered request, fall back to the manual dialog exactly once; no automatic resubmission. Verify with a fake client that rejects the first respond (dialog shown once, single respond call).
- [x] 3.3 Mirror each auto-answer to a local notification like existing sudo prompts, without including the value. Verify by inspecting the notification payload in a widget/unit test.

## 4. Settings UI and l10n

- [x] 4.1 Add an "Agent sudo credential" section to the connection settings page: Save (enter twice, confirm), Enable auto-answer (biometric/PIN gated), status line, audit list, Clear (immediate, flips toggle off). Verify with widget tests for each control's happy path and refusal paths.
- [x] 4.2 Add l10n strings to the app_en.arb template; other locales fall back to English via gen-l10n until translated. Verified with `flutter analyze` (no missing-translation errors).

## 5. Safety verification and delivery

- [x] 5.1 Add a test asserting the credential value never appears in logs, chat state, or the audit store (fake logger + audit inspection after auto-answer). Verify in the suite.
- [ ] 5.2 Run `flutter analyze` and the full `flutter test` suite green. Verify with both commands' output.
- [ ] 5.3 Manual QA over Tailscale: pair the phone, save a credential, enable auto-answer, and run a real sudo command on the Mac (e.g. `sudo sample fseventsd 1`) end-to-end; then clear the credential and confirm the manual dialog returns. Verify by observing the gateway event flow on both sides.

## Workflow follow-up

- After implementation: `/openspec-apply-change` review, then archive with `/openspec-archive-change` once merged; keep the audit of the first real auto-answered sudo in the change notes.
