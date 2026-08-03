# Decisions

- Package: `name_that_baby`; bundle/application identifier: `com.example.namethatbaby` (development-safe placeholder).
- Android minimum SDK and iOS target remain Flutter-generated defaults until physical-device support is chosen.
- The bundled database combines imported official data (currently Austria/Statistics Austria, Canada/Statistics Canada, Denmark/Statistics Denmark, Ireland/CSO, Italy/ISTAT, Norway/Statistics Norway, France/INSEE, and Spain/INE) with deterministic fixtures for uncovered countries. Manifest and UI must identify fixture coverage and must not represent the bundle as release-ready.
- Pairing uses a random 256-bit secret, shown only in the out-of-band invite; AES-GCM protects post-pairing updates. Long QR payloads use bounded multi-frame transport. Mutable state is encrypted in one local SQLite record with a separate secure-storage key; legacy preference state migrates once and is deleted. The iOS shell excludes the session database from backup.
