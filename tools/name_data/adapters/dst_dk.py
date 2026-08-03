"""Parser for Statistics Denmark's published newborn-name top-50 pages."""

from __future__ import annotations

import re
from html import unescape
from pathlib import Path

from .ssa_us import Observation, SourceFormatError


def load_decade(directory: Path) -> list[Observation]:
    rows = []
    for year in range(2015, 2025):
        file = directory / f'{year}.html'
        if not file.exists():
            raise SourceFormatError(f'Missing Statistics Denmark ranking for {year}.')
        rows.extend(_load_year(file.read_text(encoding='utf-8'), year))
    return rows


def _load_year(html: str, year: int) -> list[Observation]:
    rows = []
    tables = re.findall(r'<table\b.*?</table>', html, flags=re.DOTALL | re.IGNORECASE)
    for table in tables:
        caption = _text(re.search(r'<caption\b.*?</caption>', table, flags=re.DOTALL | re.IGNORECASE).group()) if '<caption' in table else ''
        category = {'pigenavne': 'girl', 'drengenavne': 'boy'}.get(caption.casefold())
        if category is None:
            continue
        for cells in re.findall(r'<tr\b.*?</tr>', table, flags=re.DOTALL | re.IGNORECASE):
            values = [_text(cell) for cell in re.findall(r'<td\b.*?</td>', cells, flags=re.DOTALL | re.IGNORECASE)]
            if len(values) != 4:
                continue
            try:
                rank, count = int(values[0]), int(values[2].replace('.', '').replace(' ', ''))
            except ValueError as error:
                raise SourceFormatError(f'Invalid Statistics Denmark row for {year}.') from error
            if not values[1] or rank < 1 or count < 1:
                raise SourceFormatError(f'Invalid Statistics Denmark row for {year}.')
            rows.append(Observation(values[1], category, year, count, rank))
    if len(rows) != 100 or {row.category for row in rows} != {'girl', 'boy'}:
        raise SourceFormatError(f'Statistics Denmark ranking for {year} must contain two top-50 tables.')
    return rows


def _text(markup: str) -> str:
    return ' '.join(unescape(re.sub(r'<[^>]+>', '', markup)).split())
