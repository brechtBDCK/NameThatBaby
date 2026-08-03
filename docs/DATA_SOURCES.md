# Data sources and coverage

The installed app contains no network client. Source retrieval happens only
when rebuilding `assets/data/names.sqlite`; raw files stay in ignored
`tools/name_data/raw_cache/`. Redistribution review remains required before
public distribution.

| Code | Provider / source | 2015–2024 coverage | Current status and replacement plan |
| --- | --- | --- | --- |
| US | [Social Security Administration](https://www.ssa.gov/oact/babynames/limits.html) | Fixture | `ssa_us` is implemented, but the public official `names.zip` archive and annual query endpoint currently return HTTP 403 from this build environment. Cache the official archive and rebuild when access is available; do not substitute a third-party mirror. |
| CA | [Statistics Canada table 17-10-0147-01](https://www150.statcan.gc.ca/t1/tbl1/en/tv.action?pid=1710014701) | Official import | `statcan_ca` imports the national annual rank and frequency CSV for 2015–2024. |
| BE | [Statbel](https://statbel.fgov.be/en/open-data) | Official import, reduced temporal granularity | `statbel_be` aggregates municipal counts into national 2015–2024 totals and derives ranks. The source does not expose annual rows, so this is one ten-year aggregate observation per category. |
| NL | [Sociale Verzekeringsbank](https://www.svb.nl/nl/kindernamen/namen/vorige-jaren) | Fixture | The official archive confirms annual lists for 2017–2024, but direct retrieval currently returns HTTP 403; obtain a stable export endpoint and the missing 2015–2016 lists before replacing the fixture. |
| DK | [Statistics Denmark newborn names](https://www.dst.dk/en/Statistik/emner/borgere/navne/navne-til-nyfoedte) | Official import | `dst_dk` imports the published national annual top-50 tables for 2015–2024. The publisher groups spelling variants in these lists. |
| NO | [Statistics Norway table 10467](https://data.ssb.no/api/v0/en/table/FornavnFodte) | Official import | `ssb_no` imports the official JSON-stat born-person extract for 2015–2024 and derives tied ranks from counts. |
| SE | [Statistics Sweden newborn-name table](https://www.statistikdatabasen.scb.se/pxweb/en/ssd/START__BE__BE0001__BE0001D/BE0001Nyfodda/) and [ISOF](https://www.isof.se/namn/personnamn/namnstatistik/namnstatistik-nyfodda) | Official import | `scb_se` imports SCB’s 2015–2022 series plus ISOF’s 2023 and 2024 top-100 lists (the latter sourced from the Swedish Tax Agency). ISOF groups spelling variants, unlike the earlier SCB series. |
| DE | [Gesellschaft für deutsche Sprache](https://gfds.de/vornamen/beliebteste-vornamen/) | National fallback import | `gfds_de` imports the public annual 2015–2024 first-name top tens. Germany has no national official name statistics; GfdS’s nationwide registry-office study is the documented fallback. |
| FR | [INSEE](https://www.insee.fr/fr/statistiques/8894961) | Official import | `insee_fr` imports the national civil-registration archive for 2015–2024; published values are rounded to five. |
| ES | [Instituto Nacional de Estadística](https://www.ine.es/dyngs/INEbase/es/operacion.htm?c=Estadistica_C&cid=1254736177009&idp=1254735572981&menu=resultados&secc=1254736195453) | Official import | `ine_es` imports the ten national annual ranking workbooks for 2015–2024. |
| IT | [ISTAT Baby Names](https://www.istat.it/dati/calcolatori/contanomi/) | Official import | `istat_it` imports the national annual top-100 lists for 2015–2024; the endpoint cannot return a deeper complete 2021 ranking. |
| AT | [Statistics Austria open data](https://data.statistik.gv.at/web/meta.jsp?dataset=OGDEXT_VORNAMEN_1) | Official import | `stat_at` aggregates the official district-level birth counts to national totals for 2015–2024, then derives tied ranks; the source normalizes diacritic variants. |
| GB | [ONS](https://www.ons.gov.uk/), [NRS](https://www.nrscotland.gov.uk/publications/babies-first-names-2024/), and [NISRA](https://www.nisra.gov.uk/publications/baby-names-2024) | Official import | `uk_gb` imports each complete 2015–2024 constituent series. The app derives each constituent decade list and round-robins England/Wales, Scotland, and Northern Ireland equally before GB enters the selected-country round robin. |
| IE | [Central Statistics Office](https://www.cso.ie/en/statistics/birthsdeathsandmarriages/irishbabiesnames/) | Official import | `cso_ie` imports the national CSO CSV exports for 2015–2024, retaining the top 500 ranked names per category/year. |
| AU | [NSW](https://data.nsw.gov.au/data/dataset/popular-baby-names-from-1952) and [Queensland](https://www.data.qld.gov.au/dataset/top-100-baby-names) registries | Official import, reduced geographic coverage | `nsw_au` and `qld_au` import the 2015–2024 annual series. They are round-robined equally; add other state/territory registries before treating this as nationally representative. |

For every future import, preserve the source URL, edition date, retrieval date,
attribution, raw checksum, covered years, and licensing-review status in the
generated manifest. See `tools/name_data/sources.yaml` for adapter identifiers.
