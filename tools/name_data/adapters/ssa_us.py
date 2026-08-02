"""Parser for the Social Security Administration national names archive."""

from __future__ import annotations

import csv
import io
import zipfile
from dataclasses import dataclass
from pathlib import Path


class SourceFormatError(ValueError):
    """Raised when SSA changes the documented annual-file structure."""


@dataclass(frozen=True)
class Observation:
    name: str
    category: str
    year: int
    count: int
    rank: int


def available_years(archive: Path) -> list[int]:
    with zipfile.ZipFile(archive) as source:
        years = []
        for name in source.namelist():
            if name.startswith('yob') and name.endswith('.txt') and len(name) == 11:
                try:
                    years.append(int(name[3:7]))
                except ValueError:
                    continue
    return sorted(years)


def load_decade(archive: Path, *, ending_year: int | None = None) -> list[Observation]:
    """Return the newest ten complete SSA years, with deterministic tied ranks."""
    years = available_years(archive)
    if not years:
        raise SourceFormatError('SSA archive contains no yobYYYY.txt annual files.')
    end = ending_year or years[-1]
    selected = [year for year in years if end - 9 <= year <= end]
    if len(selected) != 10:
        raise SourceFormatError(f'SSA archive lacks a complete ten-year window ending {end}.')
    records: list[Observation] = []
    with zipfile.ZipFile(archive) as source:
        for year in selected:
            try:
                text = io.TextIOWrapper(source.open(f'yob{year}.txt'), encoding='utf-8', newline='')
            except KeyError as error:
                raise SourceFormatError(f'SSA archive is missing yob{year}.txt.') from error
            by_category: dict[str, list[tuple[str, int]]] = {'F': [], 'M': []}
            with text:
                for row in csv.reader(text):
                    if len(row) != 3 or row[1] not in by_category:
                        raise SourceFormatError(f'Invalid SSA row in yob{year}.txt: {row!r}')
                    name, sex, count_text = row
                    if not name.strip() or not count_text.isdigit() or int(count_text) < 0:
                        raise SourceFormatError(f'Invalid SSA name/count in yob{year}.txt: {row!r}')
                    by_category[sex].append((name, int(count_text)))
            for sex, values in by_category.items():
                # SSA's archive is normally already rank ordered. Re-sort so a
                # changed upstream order cannot change the deterministic result.
                values.sort(key=lambda value: (-value[1], value[0].casefold()))
                previous_count: int | None = None
                rank = 0
                for index, (name, count) in enumerate(values, 1):
                    if count != previous_count:
                        rank = index
                        previous_count = count
                    records.append(
                        Observation(
                            name=name,
                            category='girl' if sex == 'F' else 'boy',
                            year=year,
                            count=count,
                            rank=rank,
                        )
                    )
    return records
