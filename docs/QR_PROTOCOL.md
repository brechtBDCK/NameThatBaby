# QR protocol

Version 1 invites contain the dataset hash, countries, categories, deterministic seed, session ID, and random 256-bit session secret. A displayed invite is an out-of-band pairing ceremony: anyone who scans it can join, so it must be regenerated before voting if exposed.

Post-pairing vote updates are base64url JSON QR envelopes encrypted with AES-256-GCM. The associated data binds protocol version, session ID, event type, and sequence number. The envelope carries a nonce, tag, and ciphertext; it never puts votes in plaintext. The receiver checks framing, version/session, authentication, replay, schema, and candidate IDs before persisting the update. The current implementation supports one QR frame only; large custom-name/Face-off updates need deterministic chunking before release.
