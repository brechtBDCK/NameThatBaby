# Data pipeline

`tools/name_data/build_database.py` creates the SQLite asset deterministically from cached source inputs. `sources.yaml` lists the intended upstream provider and adapter per country. Raw downloads are stored only under ignored `raw_cache/`; the installed app never invokes this pipeline.

The first implemented adapter is `adapters/ssa_us.py`. Place the official SSA `names.zip` archive in `tools/name_data/raw_cache/` and run the builder. It selects the newest ten complete annual `yobYYYY.txt` files, validates every row, calculates deterministic tied ranks from counts, records the raw SHA-256 in source notes, and replaces the US fixture rows. Without that archive, the builder deliberately retains fixture status in the manifest.

`adapters/insee_fr.py` imports the INSEE national ZIP archive. It excludes aggregate rare-name rows and unknown years, maps INSEE sex codes to the app categories, derives tied annual ranks from the published rounded counts, and selects 2015–2024 from the cached 2024 edition. The generated manifest preserves its raw checksum and coverage counts.

`adapters/ine_es.py` reads the national sheet from INE's ten annual newborn-name XLSX workbooks. It uses the published count ordering as the annual rank, maps NIÑOS and NIÑAS to the app categories, and imports the cached 2015–2024 workbooks without a runtime request.

`adapters/statcan_ca.py` streams Statistics Canada table 17-10-0147-01 from
its cached ZIP. It retains only the official national Frequency and Rank rows,
requires the newest ten consecutive complete years, and preserves the published
rank rather than re-ranking suppressed values.
