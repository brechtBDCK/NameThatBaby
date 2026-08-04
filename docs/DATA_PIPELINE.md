# Data pipeline

`tools/name_data/build_database.py` creates the SQLite asset deterministically from cached source inputs. `sources.yaml` lists the intended upstream provider and adapter per country. Raw downloads are stored only under ignored `raw_cache/`; the installed app never invokes this pipeline.

The builder retains the full observations only while deriving decade scores, then
materializes at most 150 ranked names per country/category in
`country_decade_ranking` for the runtime asset. Source metadata remains in
`data_source`; raw observations remain reproducible from ignored cached inputs.
The current compact asset is 228 KiB (previous observation-table asset: 60 MiB).
On this workspace, a representative three-country ranking query averages 0.227
ms over 100 warm SQLite queries. `test_deterministic_build.py` rebuilds twice
from the same cached inputs and compares checksums.

Implemented adapters load only ignored, cached official downloads. For example, `adapters/ssa_us.py` reads `names.zip`, while `adapters/dst_dk.py` reads the ten annual Statistics Denmark top-50 HTML responses in `raw_cache/dst_dk/`. The builder validates each source shape, records the raw-input SHA-256 in source notes, and retains fixture status when an official cache is absent.

`adapters/insee_fr.py` imports the INSEE national ZIP archive. It excludes aggregate rare-name rows and unknown years, maps INSEE sex codes to the app categories, derives tied annual ranks from the published rounded counts, and selects 2015–2024 from the cached 2024 edition. The generated manifest preserves its raw checksum and coverage counts.

`adapters/ine_es.py` reads the national sheet from INE's ten annual newborn-name XLSX workbooks. It uses the published count ordering as the annual rank, maps NIÑOS and NIÑAS to the app categories, and imports the cached 2015–2024 workbooks without a runtime request.

`adapters/statcan_ca.py` streams Statistics Canada table 17-10-0147-01 from
its cached ZIP. It retains only the official national Frequency and Rank rows,
requires the newest ten consecutive complete years, and preserves the published
rank rather than re-ranking suppressed values.

`adapters/ssb_no.py` reads a cached Statistics Norway table 10467 JSON-stat
extract. Its gender-prefixed source codes preserve independent girls' and boys'
entries for the same spelling; ranks are deterministically derived from counts.
