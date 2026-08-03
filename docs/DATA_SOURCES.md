# Data sources and coverage

The installed app contains no network client. Source retrieval happens only
when rebuilding `assets/data/names.sqlite`; raw files stay in ignored
`tools/name_data/raw_cache/`. Redistribution review remains required before
public distribution.

| Code | Provider / source | 2015–2024 coverage | Current status and replacement plan |
| --- | --- | --- | --- |
| US | [Social Security Administration](https://www.ssa.gov/oact/babynames/limits.html) | Fixture | `ssa_us` is implemented; cache the official `names.zip` archive, rebuild, and record its edition/retrieval metadata. |
| CA | [Statistics Canada table 17-10-0147-01](https://www150.statcan.gc.ca/t1/tbl1/en/tv.action?pid=1710014701) | Official import | `statcan_ca` imports the national annual rank and frequency CSV for 2015–2024. |
| BE | [Statbel](https://statbel.fgov.be/) | Fixture | The available 2015–2024 municipal archive has no annual field; obtain an annual national series before replacing the fixture. |
| NL | [Sociale Verzekeringsbank](https://www.svb.nl/nl/kindernamen/namen/vorige-jaren) | Fixture | The advertised public archive begins in 2017 and direct retrieval currently returns an SVB error page; obtain the missing 2015–2016 official lists and a stable source endpoint before replacing the fixture. |
| DK | [Statistics Denmark newborn names](https://www.dst.dk/en/Statistik/emner/borgere/navne/navne-til-nyfoedte) | Official import | `dst_dk` imports the published national annual top-50 tables for 2015–2024. The publisher groups spelling variants in these lists. |
| NO | [Statistics Norway table 10467](https://data.ssb.no/api/v0/en/table/FornavnFodte) | Official import | `ssb_no` imports the official JSON-stat born-person extract for 2015–2024 and derives tied ranks from counts. |
| SE | [Statistics Sweden newborn-name table](https://www.statistikdatabasen.scb.se/pxweb/en/ssd/START__BE__BE0001__BE0001D/BE0001Nyfodda/) | Fixture | Statistics Sweden's official annual series ends in 2022; obtain a Swedish Tax Agency source covering 2023–2024 before replacing the fixture. |
| DE | [Gesellschaft für deutsche Sprache](https://gfds.de/) | Fixture | Cache the documented national ranking fallback and replace the fixture after its terms and year coverage are recorded. |
| FR | [INSEE](https://www.insee.fr/fr/statistiques/8894961) | Official import | `insee_fr` imports the national civil-registration archive for 2015–2024; published values are rounded to five. |
| ES | [Instituto Nacional de Estadística](https://www.ine.es/dyngs/INEbase/es/operacion.htm?c=Estadistica_C&cid=1254736177009&idp=1254735572981&menu=resultados&secc=1254736195453) | Official import | `ine_es` imports the ten national annual ranking workbooks for 2015–2024. |
| IT | [ISTAT Baby Names](https://www.istat.it/dati/calcolatori/contanomi/) | Official import | `istat_it` imports the national annual top-100 lists for 2015–2024; the endpoint cannot return a deeper complete 2021 ranking. |
| AT | [Statistics Austria open data](https://data.statistik.gv.at/web/meta.jsp?dataset=OGDEXT_VORNAMEN_1) | Official import | `stat_at` aggregates the official district-level birth counts to national totals for 2015–2024, then derives tied ranks; the source normalizes diacritic variants. |
| GB | [ONS](https://www.ons.gov.uk/), NRS, and NISRA | Fixture | Import England/Wales, Scotland, and Northern Ireland separately, derive each ranked list, then round-robin their lists equally into one GB ranking. |
| IE | [Central Statistics Office](https://www.cso.ie/en/statistics/birthsdeathsandmarriages/irishbabiesnames/) | Official import | `cso_ie` imports the national CSO CSV exports for 2015–2024, retaining the top 500 ranked names per category/year. |
| AU | [Australian Bureau of Statistics](https://www.abs.gov.au/) and state/territory registries | Fixture | Import each available state/territory list and round-robin constituent lists equally into one AU ranking. |

For every future import, preserve the source URL, edition date, retrieval date,
attribution, raw checksum, covered years, and licensing-review status in the
generated manifest. See `tools/name_data/sources.yaml` for adapter identifiers.
