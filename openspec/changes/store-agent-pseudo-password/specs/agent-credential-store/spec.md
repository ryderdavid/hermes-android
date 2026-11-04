# Spec Delta

## Purpose
Protected on-device storage of a user-provisioned SUDO password (the Mac admin password) and consent-gated automatic answering of `sudo` requests arriving from a paired Hermes Desktop gateway, so agents can run sudo through a sanctioned channel instead of working around the password.

## ADDED Requirements

### Requirement: Protected storage of the SUDO password
The app SHALL store the SUDO password using Android Keystore-backed secure storage, scoped to a dedicated namespace separate from connection API keys. The value SHALL NOT be written to SharedPreferences, plain files, logs, analytics, chat state, or backups, and SHALL NOT be displayed in any UI.

#### Scenario: Saving the credential
- **WHEN** the user enters the SUDO password twice, both entries match, and confirms
- **THEN** the credential is stored in Keystore-backed secure storage and the plaintext entry fields are cleared

#### Scenario: Mismatched confirmation
- **WHEN** the two entered values differ
- **THEN** nothing is stored and the user is asked to re-enter

### Requirement: Auto-answer is opt-in per connection, default off
Each saved gateway connection SHALL have an independent "answer sudo automatically" toggle that defaults to OFF. Enabling the toggle SHALL require device biometric or PIN authentication. Disabling SHALL take effect immediately.

#### Scenario: Fresh connection
- **WHEN** a connection has never stored a credential
- **THEN** auto-answer is off and sudo requests show the manual dialog

#### Scenario: Enabling without biometric enrolled
- **WHEN** the device has no biometric or PIN
- **THEN** enabling auto-answer is refused with an explanation

### Requirement: Automatic answering of sudo requests
When auto-answer is enabled for a connection and a credential is stored, the app SHALL answer that connection's `sudo` server requests with the stored credential without showing the dialog. When auto-answer is off or no credential is stored, the existing manual prompt dialog SHALL be shown unchanged.

#### Scenario: Sudo request with auto-answer on
- **WHEN** a `sudo.request` event arrives on a connection with auto-answer enabled and a stored credential
- **THEN** the app responds with the stored value and does not show the dialog

#### Scenario: Sudo request with auto-answer off
- **WHEN** a `sudo.request` event arrives on a connection with auto-answer disabled
- **THEN** the manual password dialog is shown exactly as today

### Requirement: Release only to the asking paired connection
The stored credential SHALL only be sent as the answer to a `sudo` request on the connection it was saved for, over that connection's authenticated Desktop gateway WebSocket. It SHALL NOT be sent over the legacy OpenAI-compatible API, embedded in URLs or basic-auth headers, or exposed to any other endpoint.

#### Scenario: Legacy API path
- **WHEN** the app is using the OpenAI-compatible endpoint of the same connection
- **THEN** the stored credential is never transmitted on that path

### Requirement: No automatic retry after rejection
If Hermes reports that a responded credential was not accepted, the app SHALL fall back to the manual dialog for that request and SHALL NOT automatically resubmit the stored credential in a loop.

#### Scenario: Wrong stored password
- **WHEN** the stored credential is rejected by the Mac
- **THEN** the manual dialog appears once for that request and the stored credential is not resubmitted automatically

### Requirement: Local audit trail without the secret
The app SHALL record each auto-answer locally with timestamp, connection label, and request id — never the credential value — and SHALL show this audit list in the credential settings section.

#### Scenario: Reviewing auto-answers
- **WHEN** the user opens the credential section after three auto-answered sudo requests
- **THEN** three audit entries are listed with time, connection, and request id, and no entry contains the password

### Requirement: Immediate revocation
Clearing the credential SHALL delete it from secure storage immediately; afterwards auto-answer SHALL behave as if no credential is stored. Rotating the Mac's admin password SHALL be handled by re-saving the credential.

#### Scenario: Clearing the credential
- **WHEN** the user taps Clear and confirms
- **THEN** the credential is deleted, the toggle flips to off, and subsequent sudo requests show the manual dialog
