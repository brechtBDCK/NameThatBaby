# Dependencies

The app uses no HTTP, analytics, cloud, advertising, or authentication dependency.

| Dependency | Purpose |
| --- | --- |
| `shared_preferences` | One-time migration reader for pre-encrypted session state; migrated records are removed. |
| `flutter_secure_storage` | Store the 256-bit session secret and local-database encryption key in Android Keystore/iOS Keychain-backed storage. |
| `cryptography` | AES-256-GCM authenticated QR envelopes and local session encryption. |
| `qr_flutter` | On-device QR rendering. |
| `mobile_scanner` | On-device camera decoding. |
| `sqflite` | Opens the read-only bundled names database and stores the encrypted local session record; it makes no network request. |
