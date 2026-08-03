"""Parser for Central Statistics Office Ireland newborn-name CSV exports."""

from __future__ import annotations

import csv
from collections import defaultdict
from pathlib import Path

from .ssa_us import Observation, SourceFormatError


def load_decade(directory: Path) -> list[Observation]:
    return _load_file(directory / 'VSA50.csv', 'boy') + _load_file(directory / 'VSA60.csv', 'girl')


def _load_file(file: Path, category: str) -> list[Observation]:
    if not file.exists():
        raise SourceFormatError(f'Missing CSO Ireland {category} names export.')
    values = defaultdict(dict)
    with file.open(encoding='utf-8-sig', newline='') as source:
        for row in csv.DictReader(source):
            try:
                year = int(row['Year'])
            except (KeyError, ValueError):
                raise SourceFormatError(f'Invalid CSO Ireland {category} names export.') from None
            if year not in range(2015, 2025) or not row.get('VALUE'):
                continue
            statistic = row['STATISTIC']
            name = row['Boys Names' if category == 'boy' else 'Girls Names'].strip()
            if name and statistic.endswith(('C01', 'C02')):
                values[year, name]['count' if statistic.endswith('C01') else 'rank'] = int(row['VALUE'])
    output = []
    for (year, name), entry in values.items():
        if entry.get('rank', 501) <= 500 and entry.get('count', 0) > 0:
            output.append(Observation(name, category, year, entry['count'], entry['rank']))
    if {row.year for row in output} != set(range(2015, 2025)) or any(
        sum(row.year == year for row in output) < 500 for year in range(2015, 2025)
    ):
        raise SourceFormatError(f'CSO Ireland {category} export must contain 500 ranked names per year.')
    return sorted(output, key=lambda row: (row.year, row.rank, row.name.casefold()))
