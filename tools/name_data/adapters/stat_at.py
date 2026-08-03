"""Parser for Statistics Austria newborn first-name open data."""

from __future__ import annotations

import csv
from collections import defaultdict
from pathlib import Path

from .ssa_us import Observation, SourceFormatError


def load_decade(file: Path) -> list[Observation]:
    if not file.exists():
        raise SourceFormatError('Missing Statistics Austria names export.')
    counts = defaultdict(int)
    with file.open(encoding='utf-8-sig', newline='') as source:
        reader = csv.DictReader(source, delimiter=';')
        for row in reader:
            try:
                year = int(row['C-JAHR-0'])
                count = int(row['F-ANZAHL_LGEB'])
            except (KeyError, ValueError):
                raise SourceFormatError('Invalid Statistics Austria names export.') from None
            category = {'1': 'boy', '2': 'girl'}.get(row['C-GESCHLECHT-0'])
            name = row['F-VORNAME_NORMALISIERT'].strip()
            if category and name and year in range(2015, 2025) and count > 0:
                counts[year, category, name] += count
    rows = []
    for year in range(2015, 2025):
        for category in ('girl', 'boy'):
            ranking = sorted(
                ((name, count) for (row_year, row_category, name), count in counts.items()
                 if row_year == year and row_category == category),
                key=lambda row: (-row[1], row[0].casefold()),
            )
            if len(ranking) < 500:
                raise SourceFormatError(f'Statistics Austria {category} ranking for {year} is too short.')
            previous = None
            rank = 0
            for position, (name, count) in enumerate(ranking, 1):
                if count != previous:
                    rank, previous = position, count
                if rank > 500:
                    break
                rows.append(Observation(name, category, year, count, rank))
    return rows
