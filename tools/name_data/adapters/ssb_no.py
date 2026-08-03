"""Parser for Statistics Norway table 10467 JSON-stat extracts."""

from __future__ import annotations

import json
from collections import defaultdict
from pathlib import Path

from .ssa_us import Observation, SourceFormatError


def load_decade(file: Path) -> list[Observation]:
    data = json.loads(file.read_text())
    if data.get('id') != ['Fornavn', 'ContentsCode', 'Tid'] or data.get('size', [0, 0, 0])[1:] != [1, 10]:
        raise SourceFormatError('Statistics Norway extract has unexpected dimensions.')
    names = data['dimension']['Fornavn']['category']['label']
    years = data['dimension']['Tid']['category']['label']
    if list(years.values()) != [str(year) for year in range(2015, 2025)]:
        raise SourceFormatError('Statistics Norway extract must cover 2015-2024.')
    values: dict[tuple[int, str], list[tuple[str, int]]] = defaultdict(list)
    for index, (code, name) in enumerate(names.items()):
        category = {'1': 'girl', '2': 'boy'}.get(code[:1])
        if category is None:
            continue
        for offset, year in enumerate(range(2015, 2025)):
            count = data['value'][index * 10 + offset]
            if isinstance(count, (int, float)) and count > 0:
                values[year, category].append((name, int(count)))
    output = []
    for (year, category), rows in values.items():
        previous = None
        rank = 0
        for index, (name, count) in enumerate(sorted(rows, key=lambda row: (-row[1], row[0].casefold())), 1):
            if count != previous:
                rank, previous = index, count
            output.append(Observation(name, category, year, count, rank))
    if not output:
        raise SourceFormatError('Statistics Norway extract has no annual names.')
    return output
