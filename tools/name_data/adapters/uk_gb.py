"""Parsers for the three official United Kingdom constituent name sources."""

from __future__ import annotations

import csv
import io
import re
import xml.etree.ElementTree as xml
import zipfile
from pathlib import Path

from .ssa_us import Observation, SourceFormatError

_NS = '{http://schemas.openxmlformats.org/spreadsheetml/2006/main}'


def load_england_wales(file: Path) -> list[Observation]:
    """Read ONS Table 1 (girls) and Table 2 (boys), 2015–2024."""
    return _wide_year_columns(file, 'xl/worksheets/sheet4.xml', 'girl') + _wide_year_columns(
        file, 'xl/worksheets/sheet5.xml', 'boy'
    )


def load_scotland(archive: Path) -> list[Observation]:
    output = []
    with zipfile.ZipFile(archive) as source:
        name = next((item for item in source.namelist() if item.endswith('.csv') and 'metadata' not in item), None)
        if name is None:
            raise SourceFormatError('NRS archive has no name-list CSV.')
        for row in csv.DictReader(io.TextIOWrapper(source.open(name), encoding='utf-8-sig')):
            try:
                year, count, rank = int(row['Year']), int(row['Number']), int(row['Rank'])
            except (KeyError, ValueError):
                raise SourceFormatError('Invalid NRS name-list CSV.') from None
            category = {'Girl': 'girl', 'Boy': 'boy'}.get(row.get('Sex'))
            if category and 2015 <= year <= 2024 and count > 0:
                output.append(Observation(row['Name'], category, year, count, rank))
    return _require_decade(output, 'NRS')


def load_northern_ireland(file: Path) -> list[Observation]:
    """Read NISRA Table 1 (boys) and Table 2 (girls), 2015–2024."""
    return _three_column_year_blocks(file, 'xl/worksheets/sheet4.xml', 'boy') + _three_column_year_blocks(
        file, 'xl/worksheets/sheet5.xml', 'girl'
    )


def _wide_year_columns(file: Path, sheet: str, category: str) -> list[Observation]:
    rows = _xlsx_rows(file, sheet)
    header = next((row for row in rows if row.get('A') == 'Name'), None)
    if header is None:
        raise SourceFormatError('ONS workbook has no header.')
    by_year = {}
    for column, value in header.items():
        match = re.fullmatch(r'(20\d{2}) (Rank|Count)', value)
        if match:
            by_year.setdefault(int(match.group(1)), {})[match.group(2).lower()] = column
    output = []
    for row in rows:
        name = row.get('A', '').strip()
        for year, columns in by_year.items():
            rank, count = row.get(columns.get('rank', ''), ''), row.get(columns.get('count', ''), '')
            if 2015 <= year <= 2024 and name and rank.isdigit() and count.isdigit() and int(count) > 0:
                output.append(Observation(name, category, year, int(count), int(rank)))
    return _require_decade(output, 'ONS')


def _three_column_year_blocks(file: Path, sheet: str, category: str) -> list[Observation]:
    rows = _xlsx_rows(file, sheet)
    header = next((row for row in rows if any(re.fullmatch(r'20\d{2} Name', value) for value in row.values())), None)
    if header is None:
        raise SourceFormatError('NISRA workbook has no header.')
    names = {int(match.group(1)): column for column, value in header.items() if (match := re.fullmatch(r'(20\d{2}) Name', value))}
    output = []
    for row in rows:
        for year, column in names.items():
            name, count, rank = row.get(column, '').strip(), row.get(_next_column(column), ''), row.get(_next_column(_next_column(column)), '')
            if 2015 <= year <= 2024 and name and count.isdigit() and rank.isdigit() and int(count) > 0:
                output.append(Observation(name, category, year, int(count), int(rank)))
    return _require_decade(output, 'NISRA')


def _xlsx_rows(file: Path, sheet: str):
    with zipfile.ZipFile(file) as archive:
        shared = [
            ''.join(text.text or '' for text in item.iter(_NS + 't'))
            for item in xml.fromstring(archive.read('xl/sharedStrings.xml'))
        ]
        with archive.open(sheet) as source:
            for _, row in xml.iterparse(source, events=('end',)):
                if row.tag != _NS + 'row':
                    continue
                cells = {}
                for cell in row.findall(_NS + 'c'):
                    value = cell.find(_NS + 'v')
                    if value is not None and value.text is not None:
                        column = re.match(r'[A-Z]+', cell.attrib['r']).group(0)
                        cells[column] = shared[int(value.text)] if cell.attrib.get('t') == 's' else value.text
                row.clear()
                if cells:
                    yield cells


def _next_column(column: str) -> str:
    value = 0
    for letter in column:
        value = value * 26 + ord(letter) - 64
    value += 1
    output = ''
    while value:
        value, remainder = divmod(value - 1, 26)
        output = chr(remainder + 65) + output
    return output


def _require_decade(rows: list[Observation], provider: str) -> list[Observation]:
    if {row.year for row in rows} != set(range(2015, 2025)):
        raise SourceFormatError(f'{provider} source must cover 2015-2024.')
    return rows
