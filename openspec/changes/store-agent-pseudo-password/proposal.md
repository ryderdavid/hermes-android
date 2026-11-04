# Proposal: Store a protected agent SUDO password in the app

## Why

Hermes agents running on Ryder's Mac occasionally need sudo (e.g. `sample`/`spindump`/`fs_usage` captures for the bloated fseventsd diagnosis). Today the only sanctioned path is manual: the Mac emits a `sudo` server request over the Desktop gateway, the phone shows a password dialog, and Ryder types his admin password every single time. There is no user-provisioned, stored credential an agent may use, so agents either block on a human or are tempted to work around the password — which is exactly what must not happen. This change makes agent sudo use explicit and sanctioned: the credential is provisioned by the user, stored protected on the phone, and released only to the paired gateway connection that asked for it.

## What Changes

- A new **Agent SUDO password** section on a saved connection's settings page where the user can:
  - **Save** the SUDO password (Ryder's Mac admin password, entered twice for confirmation). It is stored via Android Keystore-backed secure storage — never in SharedPreferences, files, logs, or chat state.
  - **Enable/disable "Answer sudo automatically"** per connection (default: off). Enabling requires device biometric or PIN. While enabled, incoming `sudo` server requests on that connection are answered automatically with the stored credential, without showing the dialog.
  - **See status and audit**: whether a credential is stored, and a local audit list of auto-answers (timestamp, connection, request id — never the value).
  - **Clear** the credential, effective immediately.
- The manual `sudo`/`secret` prompt dialog stays exactly as-is and remains the fallback whenever auto-answer is off, no credential is stored, or Hermes rejects the stored value (no automatic retry loop).
- The credential is only ever sent as the answer to a `sudo` request on that connection's already-authenticated Desktop gateway WebSocket. It is never exposed over the legacy OpenAI-compatible API, never rendered in the UI, never logged, and never included in backups or exports.
- New capability spec: `agent-credential-store`.

## Capabilities

### New Capabilities
- `agent-credential-store`: Protected on-device storage of the agent pseudo-password and consent-gated automatic answering of gateway `sudo` requests.

### Modified Capabilities
- None. The existing prompt/dialog behavior is unchanged; this adds an opt-in path beside it.

## Impact

- New: `lib/core/services/agent_credential_service.dart` (wraps the existing `CredentialStore` abstraction with a dedicated Keystore namespace), per-connection auto-answer preference, auto-answer hook in the sensitive-prompt flow in `chat_screen.dart` / `gateway_turn_application_controller.dart`, audit store, settings UI section, and l10n strings in all locales.
- Changed: `pubspec.yaml` gains `local_auth` for the biometric/PIN gate.
- Uses existing: `flutter_secure_storage` 10.3.1 (`FlutterSecureCredentialStore` in `connection_manager.dart`).
- No changes on the Mac side: Hermes already emits `sudo` server requests and accepts answers over the gateway.
