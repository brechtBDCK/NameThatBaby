# Privacy

There is no account, server, analytics, advertising, remote config, or runtime network permission. Bundled name assets work offline. Session configuration and votes are AES-256-GCM encrypted in a local SQLite database; the separate encryption key and session secret are stored through the secure-storage plugin. Android backups and device-transfer extraction are disabled in the production manifest. Session deletion removes the encrypted record and both locally stored keys.

Existing preference records are read once, re-encrypted into SQLite, and deleted. Secure-storage keys explicitly opt out of iCloud Keychain synchronization. The iOS native shell marks the local session database as excluded from backup; a real-device security review remains a release blocker. The app does not log QR payloads, choices, or secrets.
