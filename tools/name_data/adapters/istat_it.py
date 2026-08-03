"""Parser for ISTAT's published newborn-name ranking responses."""
import json
from pathlib import Path

from .ssa_us import Observation, SourceFormatError


def load_decade(directory: Path) -> list[Observation]:
    output = []
    for year in range(2015, 2025):
        text = (directory / f'{year}.jsonp').read_text(encoding='utf-8')
        if not text.startswith('callback(') or not text.endswith(');'):
            raise SourceFormatError(f'Invalid ISTAT ranking for {year}.')
        data = json.loads(text[9:-2])
        rows = data.get('0', []) + data.get('1', [])
        if len(rows) != 200:
            raise SourceFormatError(f'ISTAT ranking for {year} must contain 100 names per category.')
        previous = {'m': None, 'f': None}
        ranks = {'m': 0, 'f': 0}
        positions = {'m': 0, 'f': 0}
        for row in rows:
            gender, count, name = row.get('gender'), row.get('count'), row.get('name', '').strip()
            if gender not in previous or not isinstance(count, int) or not name:
                raise SourceFormatError(f'Invalid ISTAT row for {year}.')
            positions[gender] += 1
            if count != previous[gender]:
                ranks[gender], previous[gender] = positions[gender], count
            output.append(Observation(name, {'m': 'boy', 'f': 'girl'}[gender], year, count, ranks[gender]))
    return output
