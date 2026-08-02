"""Parser for INE's annual national newborn-name XLSX workbooks."""

from __future__ import annotations

import re
import xml.etree.ElementTree as xml
import zipfile
from pathlib import Path

from .ssa_us import Observation, SourceFormatError

_NS = {'x': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}


def load_decade(directory: Path) -> list[Observation]:
    files = sorted(directory.glob('nomnac*.xlsx'))
    if len(files) != 10:
        raise SourceFormatError('INE source must contain exactly ten annual workbooks.')
    observations: list[Observation] = []
    for file in files:
        year = 2000 + int(re.search(r'(\d{2})\.xlsx$', file.name).group(1))
        observations.extend(_load_year(file, year))
    return observations


def _load_year(file: Path, year: int) -> list[Observation]:
    with zipfile.ZipFile(file) as archive:
        shared = [
            ''.join(text.text or '' for text in item.iter('{http://schemas.openxmlformats.org/spreadsheetml/2006/main}t'))
            for item in xml.fromstring(archive.read('xl/sharedStrings.xml'))
        ]
        root = xml.fromstring(archive.read('xl/worksheets/sheet2.xml'))
    rankings = {'boy': [], 'girl': []}
    for row in root.findall('.//x:row', _NS):
        cells = {}
        for cell in row.findall('x:c', _NS):
            value = cell.find('x:v', _NS)
            if value is None: continue
            column = re.match(r'[A-Z]+', cell.attrib['r']).group(0)
            cells[column] = shared[int(value.text)] if cell.attrib.get('t') == 's' else value.text
        for name_column, count_column, category in [('A', 'B', 'boy'), ('D', 'E', 'girl')]:
            name, count = cells.get(name_column), cells.get(count_column)
            if name and count and name != 'TOTAL' and count.isdigit():
                rankings[category].append((name.title(), int(count)))
    output: list[Observation] = []
    for category, rows in rankings.items():
        previous_count = None
        rank = 0
        for index, (name, count) in enumerate(rows, 1):
            if count != previous_count:
                rank = index
                previous_count = count
            output.append(Observation(name, category, year, count, rank))
    if not output: raise SourceFormatError(f'INE workbook has no national rankings: {file.name}')
    return output
