# Privacy

There is no account, server, analytics, advertising, remote config, or runtime network permission. Bundled name assets work offline. Session configuration and votes are persisted locally; the session secret is stored through the secure-storage plugin. Android backups and device-transfer extraction are disabled in the production manifest. Session deletion removes the persisted state and secure key.

The current mutable session data is stored in preferences rather than an encrypted SQLite database; moving it to encrypted local SQLite, adding explicit iOS file-backup exclusion, and a real-device security review remain release blockers. The app does not log QR payloads, choices, or secrets.
