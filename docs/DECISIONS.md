# Decisions

- Package: `name_that_baby`; bundle/application identifier: `com.example.namethatbaby` (development-safe placeholder).
- Android minimum SDK and iOS target remain Flutter-generated defaults until physical-device support is chosen.
- The bundled database is a deterministic fixture while official data adapters are completed. Manifest and UI must not represent it as production coverage.
- Pairing uses a random 256-bit secret, shown only in the out-of-band invite; AES-GCM protects post-pairing updates. Multi-frame QR support and a persistent encrypted SQLite session database remain release tasks.
