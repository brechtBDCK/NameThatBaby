# Dependencies

The app uses no HTTP, analytics, cloud, advertising, or authentication dependency.

| Dependency | Purpose |
| --- | --- |
| `shared_preferences` | Persist non-secret local session state. |
| `flutter_secure_storage` | Store the 256-bit session secret in Android Keystore/iOS Keychain-backed storage. |
| `cryptography` | AES-256-GCM authenticated update envelopes. |
| `qr_flutter` | On-device QR rendering. |
| `mobile_scanner` | On-device camera decoding. |
