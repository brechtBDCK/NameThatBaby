"""Parser for INSEE's national French first-name CSV archive."""

from __future__ import annotations

import csv
import io
import zipfile
from collections import defaultdict
from pathlib import Path

from .ssa_us import Observation, SourceFormatError


def load_decade(archive: Path) -> list[Observation]:
    """Load the latest ten complete French years and calculate tied ranks."""
    with zipfile.ZipFile(archive) as source:
        names = [name for name in source.namelist() if name.lower().endswith('.csv')]
        if len(names) != 1:
            raise SourceFormatError('INSEE archive must contain exactly one national CSV.')
        with io.TextIOWrapper(source.open(names[0]), encoding='utf-8-sig', newline='') as text:
            rows = list(csv.DictReader(text, delimiter=';'))
    required = {'sexe', 'prenom', 'periode', 'valeur'}
    if not rows or not required.issubset(rows[0]):
        raise SourceFormatError('INSEE CSV has unexpected column names.')
    values: dict[tuple[int, str], list[tuple[str, int]]] = defaultdict(list)
    for row in rows:
        if row['periode'] == 'XXXX' or row['prenom'] == '_PRENOMS_RARES_':
            continue
        try:
            year = int(row['periode'])
            sex = int(row['sexe'])
            count = int(row['valeur'])
        except (TypeError, ValueError) as error:
            raise SourceFormatError(f'Invalid INSEE row: {row!r}') from error
        if sex not in (1, 2) or year < 1900 or count < 1 or not row['prenom'].strip():
            raise SourceFormatError(f'Invalid INSEE row: {row!r}')
        values[year, 'boy' if sex == 1 else 'girl'].append((row['prenom'], count))
    years = sorted({year for year, _ in values})
    if not years:
        raise SourceFormatError('INSEE CSV has no annual observations.')
    selected = [year for year in years if years[-1] - 9 <= year <= years[-1]]
    if len(selected) != 10:
        raise SourceFormatError('INSEE CSV lacks a complete ten-year window.')
    observations: list[Observation] = []
    for year in selected:
        for category in ('girl', 'boy'):
            ranked = sorted(values[year, category], key=lambda row: (-row[1], row[0].casefold()))
            previous_count = None
            rank = 0
            for index, (name, count) in enumerate(ranked, 1):
                if count != previous_count:
                    rank = index
                    previous_count = count
                observations.append(Observation(name, category, year, count, rank))
    return observations
