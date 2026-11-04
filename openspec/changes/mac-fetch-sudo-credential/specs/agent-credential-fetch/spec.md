# Spec Delta

## Purpose
On-demand serving of the stored SUDO password to the paired Mac over the authenticated Desktop gateway, gated per connection and audited, so unattended Mac-side agents can obtain sudo credentials through a user-provisioned channel.

## ADDED Requirements

### Requirement: Fetch permission is opt-in per connection, default off
Each saved connection SHALL have an independent "allow Mac to fetch SUDO password" toggle, default OFF, separate from the auto-answer toggle. Enabling SHALL require device biometric or PIN. Disabling SHALL take effect immediately.

#### Scenario: Default state
- **WHEN** the user opens the Agent SUDO password card on a connection that only has auto-answer enabled
- **THEN** the fetch toggle is off and `agent_credential.request` messages are refused

### Requirement: Serving fetch requests
When an `agent_credential.request` server request arrives on a connection with fetch enabled and a stored SUDO password, the app SHALL respond with the stored value and SHALL NOT show any dialog, display, or log the value.

#### Scenario: Fetch enabled
- **WHEN** the paired Mac sends `agent_credential.request` on a connection with fetch enabled and a stored password
- **THEN** the app responds with the stored value once and records an audit entry of kind `fetch`

#### Scenario: Fetch disabled
- **WHEN** the paired Mac sends `agent_credential.request` on a connection with fetch disabled
- **THEN** the app responds with a refusal containing no credential material and no dialog appears

### Requirement: Audit distinguishes fetches from auto-answers
Audit entries SHALL carry a kind (`auto_answer` or `fetch`) alongside timestamp, connection label, and request id, and SHALL never contain the credential value.

#### Scenario: Reviewing mixed activity
- **WHEN** the audit list contains both auto-answered sudo requests and credential fetches
- **THEN** each entry shows its kind, time, connection, and request id, with no value anywhere

### Requirement: Value only to the paired connection
The stored value SHALL only be sent in response to `agent_credential.request` on the connection it was saved for, over that connection's authenticated gateway WebSocket. It SHALL NOT be exposed on the legacy API, in URLs, headers, or any other endpoint.

#### Scenario: Non-gateway path
- **WHEN** any non-gateway code path asks for the credential
- **THEN** it is never provided

### Requirement: Revocation stops fetches immediately
Clearing the stored password or disabling the fetch toggle SHALL prevent any further fetch responses on that connection.

#### Scenario: Clearing the password
- **WHEN** the user clears the SUDO password while a fetch request is in flight or afterwards
- **THEN** no further fetch response carries the value
