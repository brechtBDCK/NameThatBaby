"""Parser for Statistics Sweden's newborn-name bulk CSV."""
import csv
import io
import re
import xml.etree.ElementTree as xml
import zipfile
from collections import defaultdict
from pathlib import Path

from .ssa_us import Observation, SourceFormatError


_NS = '{http://schemas.openxmlformats.org/spreadsheetml/2006/main}'


def load_decade(archive: Path, later_years: Path | None = None) -> list[Observation]:
    counts = defaultdict(list)
    with zipfile.ZipFile(archive) as source:
        name = next((item for item in source.namelist() if item.endswith('.csv')), None)
        if name is None:
            raise SourceFormatError('Statistics Sweden archive has no CSV.')
        reader = csv.DictReader(io.TextIOWrapper(source.open(name), encoding='cp1252'))
        for row in reader:
            year = int(row['year'])
            count = row['Number of children born']
            category = {'girls': 'girl', 'boys': 'boy'}.get(row['sex'])
            if category and 2015 <= year <= 2022 and count.isdigit() and int(count) > 0:
                counts[year, category].append((row['first name normally used'], int(count)))
    output = []
    for (year, category), rows in counts.items():
        previous = None
        rank = 0
        for position, (name, count) in enumerate(sorted(rows, key=lambda row: (-row[1], row[0].casefold())), 1):
            if count != previous:
                rank, previous = position, count
            output.append(Observation(name, category, year, count, rank))
    if later_years:
        output.extend(_load_isof(later_years / '2023.xlsx', 2023))
        output.extend(_load_isof(later_years / '2024.xlsx', 2024))
    expected = set(range(2015, 2025 if later_years else 2023))
    if {row.year for row in output} != expected:
        raise SourceFormatError('Statistics Sweden sources must cover every requested complete year.')
    return output


def _load_isof(file: Path, year: int) -> list[Observation]:
    if not file.exists():
        raise SourceFormatError(f'Missing ISOF Sweden {year} workbook.')
    output = []
    for sheet, category in (('sheet1.xml', 'girl'), ('sheet2.xml', 'boy')):
        for row in _xlsx_rows(file, f'xl/worksheets/{sheet}'):
            columns = ('B', 'D', 'E') if year == 2023 and category == 'girl' else ('A', 'C', 'D')
            rank, name, count = (row.get(column, '') for column in columns)
            if rank.isdigit() and name and count.isdigit() and int(count) > 0:
                output.append(Observation(name.title(), category, year, int(count), int(rank)))
    if sum(row.category == 'girl' for row in output) < 100 or sum(row.category == 'boy' for row in output) < 100:
        raise SourceFormatError(f'ISOF Sweden {year} workbook must contain two top-100 lists.')
    return output


def _xlsx_rows(file: Path, sheet: str):
    with zipfile.ZipFile(file) as archive:
        shared = [''.join(text.text or '' for text in item.iter(_NS + 't')) for item in xml.fromstring(archive.read('xl/sharedStrings.xml'))]
        with archive.open(sheet) as source:
            for _, row in xml.iterparse(source, events=('end',)):
                if row.tag != _NS + 'row':
                    continue
                values = {}
                for cell in row.findall(_NS + 'c'):
                    value = cell.find(_NS + 'v')
                    if value is not None and value.text is not None:
                        column = re.match(r'[A-Z]+', cell.attrib['r']).group(0)
                        values[column] = shared[int(value.text)] if cell.attrib.get('t') == 's' else value.text
                row.clear()
                if values:
                    yield values
