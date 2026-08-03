"""Parser for Queensland's official annual top-100 name DataStore exports."""

import json
from pathlib import Path

from .ssa_us import Observation, SourceFormatError


def load_decade(directory: Path) -> list[Observation]:
    output = []
    for year in range(2015, 2025):
        try:
            records = json.loads((directory / f'{year}.json').read_text())['result']['records']
        except (FileNotFoundError, KeyError, json.JSONDecodeError):
            raise SourceFormatError(f'Invalid Queensland {year} DataStore export.') from None
        for rank, row in enumerate(records, 1):
            for name_key, count_key, category in (('Girl Names', 'Count of Girl Names', 'girl'), ('Boy Names', 'Count of Boy Names', 'boy')):
                name, count = str(row.get(name_key, '')).strip(), str(row.get(count_key, ''))
                if name and count.isdigit() and int(count) > 0:
                    output.append(Observation(name, category, year, int(count), rank))
    if len(output) < 2000:
        raise SourceFormatError('Queensland source must contain both top-100 lists for every year.')
    return output
