# Proposal: Let the paired Mac fetch the stored SUDO password on demand

## Why

`store-agent-pseudo-password` stores the SUDO password Keystore-protected on the phone and auto-answers `sudo.request` events during phone-driven gateway chats. But an agent running unattended on the Mac itself (CLI/TUI session, no phone chat open) still has no sanctioned way to sudo — the phone-held credential is unreachable from there, by design. This change adds the missing leg: when enabled, the paired Mac's Hermes can explicitly request the stored credential from the phone over the existing gateway connection, so unattended Mac-side agents can run sudo through a user-provisioned, audited channel instead of ad-hoc workarounds.

## What Changes

- A new per-connection setting **"Allow Mac to fetch SUDO password"** (default OFF), separate from the auto-answer toggle. Enabling it requires biometric/PIN, same as auto-answer.
- The app SHALL handle a new gateway server-request method `agent_credential.request`: when it arrives on a connection with fetch enabled and a stored credential, the app responds with the stored value (never logged/displayed), records an audit entry marked `fetch`, and mirrors a notification. If fetch is disabled or no credential is stored, the app responds with an explicit refusal and shows nothing sensitive.
- The existing `sudo.request` auto-answer path is unchanged.
- Mac-side (cross-repo, Hermes desktop/agent — implementation lives outside this repo): the gateway server sends `agent_credential.request` on the paired control connection when a local agent needs sudo and no machine-local credential is configured; the terminal sudo path then uses the returned value exactly like `SUDO_PASSWORD`.

## Capabilities

### New Capabilities
- `agent-credential-fetch`: On-demand serving of the stored SUDO password to the paired Mac over the gateway, gated per connection and audited.

### Modified Capabilities
- `agent-credential-store`: the settings card gains the fetch toggle and the audit entries gain a `fetch` kind.

## Impact

- App: new server-request handler in the Desktop gateway client path, new preference + toggle in `AgentCredentialCard`, audit entry kind, l10n keys.
- Cross-repo: Hermes desktop gateway + local terminal sudo integration (separate change in the Hermes repo) — specified here as the consumer contract only.
- No change to the wire format of existing `sudo.request`/`sudo.respond`.
