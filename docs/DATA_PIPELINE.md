# Data pipeline

`tools/name_data/build_database.py` creates the SQLite asset deterministically from fixture-shaped records. `sources.yaml` lists the intended upstream provider and adapter per country. Real adapters must cache raw files under ignored `raw_cache/`, validate text, rank, category and years, aggregate ten complete annual datasets with `1 / log2(rank + 1)`, and write source edition/checksum metadata. The app never invokes this pipeline.
