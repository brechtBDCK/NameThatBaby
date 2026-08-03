"""Parser for Statistics Canada annual first-name table 17-10-0147-01."""

from __future__ import annotations

import csv
import io
import zipfile
from collections import defaultdict
from pathlib import Path

from .ssa_us import Observation, SourceFormatError


def load_decade(archive: Path) -> list[Observation]:
    """Return the newest complete ten Canadian years with official ranks."""
    with zipfile.ZipFile(archive) as source:
        name = next((item for item in source.namelist() if item.endswith('.csv') and 'MetaData' not in item), None)
        if name is None:
            raise SourceFormatError('Statistics Canada archive has no data CSV.')
        years = _years(source, name)
        selected = years[-10:]
        if len(selected) != 10 or selected != list(range(selected[-1] - 9, selected[-1] + 1)):
            raise SourceFormatError('Statistics Canada archive lacks a complete ten-year window.')
        values: dict[tuple[int, str, str], dict[str, int]] = defaultdict(dict)
        with io.TextIOWrapper(source.open(name), encoding='utf-8-sig', newline='') as text:
            for row in csv.DictReader(text):
                year = _year(row)
                category = {'Male': 'boy', 'Female': 'girl'}.get(row.get('Sex at birth'))
                indicator = row.get('Indicator')
                name = row.get('First name at birth', '').strip()
                if year not in selected or category is None or indicator not in {'Frequency', 'Rank'} or not name:
                    continue
                try:
                    values[year, category, name][indicator] = int(float(row['VALUE']))
                except (KeyError, TypeError, ValueError):
                    continue  # Suppressed values have no usable rank or count.
    observations = [
        Observation(name, category, year, value['Frequency'], value['Rank'])
        for (year, category, name), value in values.items()
        if {'Frequency', 'Rank'} <= value.keys()
    ]
    if not observations or {row.category for row in observations} != {'girl', 'boy'}:
        raise SourceFormatError('Statistics Canada archive has no ranked annual names.')
    return sorted(observations, key=lambda row: (row.year, row.category, row.rank, row.name.casefold()))


def _years(source: zipfile.ZipFile, name: str) -> list[int]:
    with io.TextIOWrapper(source.open(name), encoding='utf-8-sig', newline='') as text:
        years = {_year(row) for row in csv.DictReader(text)}
    return sorted(year for year in years if year is not None)


def _year(row: dict[str, str]) -> int | None:
    try:
        return int(row.get('REF_DATE', ''))
    except ValueError:
        return None
