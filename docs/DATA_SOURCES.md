# Data sources and coverage

| Codes | Intended provider | Status |
| --- | --- | --- |
| US | Social Security Administration | Adapter implemented; fixture remains until the official archive is cached locally |
| CA | Statistics Canada | Fixture pending official import |
| BE, NL, DK, NO, SE, AT, IE | National statistics/civil sources | Fixture pending official import |
| FR | INSEE | Official national CSV imported: 2015–2024; redistribution review remains required |
| ES | Instituto Nacional de Estadística | Official national newborn rankings imported: 2015–2024; redistribution review remains required |
| IT | ISTAT | Fixture pending official import |
| GB | ONS + NRS + NISRA aggregated equally by constituent list | Fixture pending official import |
| AU | State/territory lists aggregated equally by state list | Fixture pending official import |
| DE | Authoritative documented national ranking fallback | Fixture pending official import |

Exact URLs are in `tools/name_data/sources.yaml`. Every source needs edition, retrieval date, redistribution assessment, and real coverage confirmation before release.
