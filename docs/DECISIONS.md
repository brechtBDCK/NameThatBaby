# Decisions

- Package: `name_that_baby`; bundle/application identifier: `com.example.namethatbaby` (development-safe placeholder).
- Android minimum SDK and iOS target remain Flutter-generated defaults until physical-device support is chosen.
- The bundled database exposes only verified imported official or documented fallback sources. US and NL remain unavailable until an official cached source can be validated; fixture/template rows are never materialized into the selectable runtime pool.
- Pairing uses a random 256-bit secret, shown only in the out-of-band invite; AES-GCM protects post-pairing updates. Long QR payloads use bounded multi-frame transport. Mutable state is encrypted in one local SQLite record with a separate secure-storage key; legacy preference state migrates once and is deleted. The iOS shell excludes the session database from backup.
- Persisted state version 4 adds ordered `countryPriority`. Version-3 country sets migrate without losing codes using stable lexical order; version-4 preserves the explicit saved order. The next successful write upgrades the serialized shape.
- Runtime data schema version 2 materializes compact country-popularity metadata beside each decade ranking. Candidate presentation uses country context rather than an ambiguous rank after the deterministic discovery shuffle; pairing/session protocol and persisted session schema are unchanged.
