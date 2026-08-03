"""Parser for New South Wales' official annual baby-name CSV."""

import csv
from pathlib import Path

from .ssa_us import Observation, SourceFormatError


def load_decade(file: Path) -> list[Observation]:
    output = []
    with file.open(encoding='utf-8-sig', newline='') as source:
        for row in csv.DictReader(source):
            try:
                year, count, rank = int(row['Year']), int(row['Number']), int(row['Rank'])
            except (KeyError, ValueError):
                raise SourceFormatError('Invalid NSW baby-name CSV.') from None
            category = {'Female': 'girl', 'Male': 'boy'}.get(row.get('Gender'))
            name = row.get('Name', '').strip()
            if category and name and 2015 <= year <= 2024 and count > 0:
                output.append(Observation(name.title(), category, year, count, rank))
    if {row.year for row in output} != set(range(2015, 2025)):
        raise SourceFormatError('NSW source must cover 2015-2024.')
    return output
