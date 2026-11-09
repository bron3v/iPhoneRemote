# Security and local data handling

**English** · [Italiano](SECURITY.it.md)

## Trust model

This app requires an iPhone you control, the ability to unlock it, and the
approvals required by iOS. WDA is a development runner that uses private XCTest
APIs; it does not bypass Developer Mode, trust, provisioning, or authentication.
The keypad guide is only a manual visual reference: it does not reveal protected
keys, verify a passcode, or guarantee alignment.

The Mac client and iproxy tunnel use `127.0.0.1:8100` and explicitly select
USB/UDID. This restricts the listener on the Mac; **it does not by itself guarantee
that the WDA server on the phone is restricted to loopback**. The runner retains
upstream behavior and may listen on the device's network interfaces.
Do not expose WDA through port forwarding or use it as a public remote service.
It is not an authenticated control service for untrusted networks.

The app adds no daemons, login items, or global changes to `xcode-select`.
It terminates processes it starts, not those owned by other tools. If the Mac
process is force-terminated, you may need to stop remaining helpers manually.
Normal shutdown finalizes recordings and stops the app's own helpers.

## Data

- Video and commands stay local; there is no telemetry or application backend.
- Screenshots and recordings are saved only on request, in the selected folder.
- Unconfirmed text remains in memory and can be copied explicitly.
- The personal app package contains a device identifier, Team, and provisioning
  profile; it is not the source archive intended for sharing.
- Signing and renewal may contact Apple; the bootstrap downloads WDA from GitHub.
- Xcode logs and diagnostics may contain identities, UDIDs, paths, or other
  personal data. Do not attach them to issues in full.

## Reporting security issues

Do not publish keys, tokens, provisioning profiles, Apple Account details,
passcodes, or phone content in an issue. If GitHub private vulnerability reporting
is enabled for this repository, use that channel. If it is unavailable, open a
neutral request to arrange a private channel, without exploitable details or
sensitive data. Private vulnerability reporting must be enabled by the repository
owner after creation; this document does not claim it is already enabled.

Before publishing, run `python3 Scripts/publication_audit.py` on the staged files
and review the diff. The audit detects some risky patterns and files, but does not
replace a review. If a credential is exposed, revoke it: deleting it only from the
latest version does not remove it from Git history.
