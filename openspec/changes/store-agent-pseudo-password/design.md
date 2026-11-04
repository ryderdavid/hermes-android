# Design

## Context

The Mac's Hermes already emits `sudo.request` / `secret.request` server requests over the Desktop gateway WebSocket; the app queues them (`chat_screen.dart` `_queueSensitivePrompt`) and shows `GatewaySensitivePromptDialog`, where the user types the value per request. `GatewaySensitivePromptRequest` deliberately carries no value, and `respondToSudo` sends it straight to the gateway. The app already has a `CredentialStore` abstraction with `FlutterSecureCredentialStore` (Android Keystore via `flutter_secure_storage` 10.3.1, namespace `hermes_android_connections`) used for connection API keys. See proposal.md for motivation.

## Goals / Non-Goals

**Goals:**
- Let the user provision one pseudo-password (the Mac admin password) once, stored hardware-backed, and let the app answer `sudo` requests on the paired connection automatically when enabled.
- Keep every existing safety property: value never logged, never in chat state, never displayed, manual dialog remains the default and the fallback.

**Non-Goals:**
- No Mac-side changes; the gateway protocol already supports sudo answers.
- No auto-answer for `secret` requests (only `sudo`), no cross-connection sharing, no cloud sync, no export.
- Not a general password manager.

## Decisions

1. **Reuse the `CredentialStore` abstraction, dedicated namespace.** New `AgentCredentialService` wraps `FlutterSecureCredentialStore` with `storageNamespace: 'hermes_android_agent_credentials'`, so wiping connection credentials never touches the pseudo-password and vice versa. Keys: `sudo_password`, prefixed per connection id. Alternative considered: one shared namespace — rejected because a connection-credential reset would silently delete the sudo credential.
2. **Fail closed on storage errors.** If the Keystore read errors, treat the credential as absent (manual dialog) and require re-saving; never fall back to plaintext or SharedPreferences. `resetOnError: true` for this namespace so a corrupted keystore entry is wiped rather than trusted. Alternative: `resetOnError: false` like connections — rejected for a credential; silently losing it is safer than using a corrupt one.
3. **Auto-answer preference in SharedPreferences, secret in Keystore.** The per-connection toggle (`auto_answer_sudo` keyed by connection id) is non-secret and lives in SharedPreferences; only the value lives in secure storage.
4. **Hook point: before the dialog is queued.** In the sensitive-prompt flow, when event type is `sudo.request`, the connection has auto-answer on, and a credential is stored, respond immediately via the existing `respondToSudo` path, record an audit entry, and skip `_queueSensitivePrompt`. On rejection (respond throws / `sudo.expire` without acceptance), fall back to the manual dialog once. Alternative: hook inside the dialog — rejected, because then the dialog still appears.
5. **Biometric/PIN gate via `local_auth` for enabling auto-answer and for revealing stored-status details.** Falls back to device PIN when no biometrics are enrolled; refuses if neither exists. New dependency `local_auth` in pubspec.yaml. Alternative: re-typing the pseudo-password to enable — kept as the fallback when local_auth is unavailable.
6. **Transport unchanged.** The value travels only inside the existing `respondToSudo` WebSocket message to the paired connection's gateway — the same channel that already carries manually typed passwords today. No new network surface.
7. **Backup exclusion.** AndroidOptions for this namespace: `migrateWithBackup: false`, so the credential is not carried into device backups/transfers. (Connection keys use `migrateWithBackup: true`; a sudo password must not.)
8. **Audit store in SharedPreferences as JSON**: list of `{timestamp, connectionId, connectionLabel, requestId}`. Never the value. Capped at e.g. 200 entries.

## Risks / Trade-offs

- **[Risk] The real Mac admin password now lives on the phone.** → Hardware-backed Keystore (StrongBox when available), excluded from backups, never displayed/logged, biometric gate to change settings, one-tap clear, and a visible audit list. Alternative of a dedicated low-privilege `hermes-agent` account with narrow NOPASSWD sudoers was offered and declined by the user; documented here as the lower-risk option if this is ever reconsidered.
- **[Risk] Phone theft or malware could exfiltrate the password via auto-answer.** → Auto-answer only answers requests arriving on the paired, authenticated gateway connection; the Mac must be the requester, and each answer is auditable on the phone. Revocation = clear credential or rotate the Mac password.
- **[Risk] Keystore unavailable after OS updates / device change.** → Fail closed: manual dialog appears and the user re-saves. Documented in the settings UI.
- **[Risk] Auto-answer loop if the Mac keeps rejecting.** → One automatic attempt per request id; rejection falls back to the manual dialog, no resubmission (spec requirement).
- **[Trade-off] Storing the admin password (user's choice) vs. a pseudo-account.** → Accepted with the mitigations above; the design keeps the door open to swapping the stored value for a dedicated account's password later without protocol changes.

## Migration Plan

No migration: purely additive, default-off feature. Rollback: disable the toggle and/or clear the credential in the app; no server or Mac changes to undo.

## Open Questions

- Should the audit list also trigger a local notification on each auto-answer (like clarify/sudo prompts already mirror to notifications)? Assumed yes — matches existing prompt-mirroring behavior; can be dropped without changing the specs.
