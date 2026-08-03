# QR protocol

Version 4 invites contain the dataset hash, countries, categories, deterministic seed, session ID, creator participant ID, and random 256-bit session secret. A displayed invite is an out-of-band pairing ceremony: anyone who scans it can join, so it must be regenerated before voting if exposed.

Post-pairing vote updates are base64url JSON QR envelopes encrypted with AES-256-GCM. The associated data binds protocol version, session ID, event type, sender, and sequence number. The envelope carries an authenticated sender participant ID, nonce, tag, and ciphertext; it never puts votes in plaintext. The receiver checks framing, version/session, authentication, sender-scoped replay, schema, and candidate IDs before persisting the update.

When an encrypted packet exceeds the display threshold it is split into at most 16 `NTB3F` frames. Each frame carries a random transfer ID, frame index, total count, and SHA-256 packet digest. The scanner reassembles frames in any order, rejects mixed transfers, verifies the digest, and only then decrypts the original authenticated packet. The choosing-update display provides a manual Next frame control; the scanner reports partial-frame progress.

`choosing_votes` carries only the local vote snapshot. `custom_names` carries custom-name lists by category and is exchanged in both directions before Face-off; each device merges by normalized key/category and sorts deterministically. `faceoff_votes` carries one completed category round: the round index, ordered pairings, and each local left/right/skip choice. A receiver accepts it only when its own active round has the exact same category and pairings; both devices then score unanimous choices as 3 points, split choices as 1–1, and skips as unscored.

After an invite is scanned, the joining phone displays an encrypted `pair_accept` QR. The creator scans it to bind the second participant ID. Both phones then derive the same six-digit confirmation code using HMAC-SHA-256 over the session secret and the sorted participant IDs. Users compare this code before choosing names.

## Compatibility

The active wire format is version 4. It authenticates the source participant
identifier as AES-GCM associated data, so replay detection is scoped to a sender
and an attacker cannot relabel an encrypted packet. Version-1, version-2, and version-3
pairing invitations are detected and rejected with a renewal message; those
sessions must pair again before further synchronization.
