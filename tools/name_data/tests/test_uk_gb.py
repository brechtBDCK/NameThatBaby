import tempfile
import unittest
import zipfile
from pathlib import Path

from tools.name_data.adapters.uk_gb import load_england_wales, load_northern_ireland, load_scotland


class UkGbAdapterTest(unittest.TestCase):
    def test_parses_all_three_official_constituent_formats(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            ons, nisra, nrs = folder / 'ons.xlsx', folder / 'nisra.xlsx', folder / 'nrs.zip'
            _xlsx(ons, ons=True)
            _xlsx(nisra, ons=False)
            with zipfile.ZipFile(nrs, 'w') as source:
                rows = ['Year,Sex,Name,Number,Rank']
                for year in range(2015, 2025):
                    rows += [f'{year},Boy,Alf,10,1', f'{year},Girl,Ada,12,1']
                source.writestr('full-list.csv', '\n'.join(rows))
            self.assertEqual(len(load_england_wales(ons)), 20)
            self.assertEqual(len(load_northern_ireland(nisra)), 20)
            self.assertEqual(len(load_scotland(nrs)), 20)


def _xlsx(path, *, ons):
    shared = []
    rows = []
    for year in range(2015, 2025):
        if ons:
            rows.append((f'{year} Rank', '1', f'{year} Count', '10'))
        else:
            rows.append((f'{year} Name', 'Alf', 'Number of Babies', '10', 'Rank', '1'))
    for sheet in ('sheet4.xml', 'sheet5.xml'):
        cells = []
        if ons:
            headers = [('A', 'Name')]
            for index, (rank, _, count, _) in enumerate(rows):
                headers += [(_column(index * 2 + 2), rank), (_column(index * 2 + 3), count)]
            data = [('A', 'Ada' if sheet == 'sheet4.xml' else 'Alf')]
            for index in range(10): data += [(_column(index * 2 + 2), '1'), (_column(index * 2 + 3), '10')]
        else:
            headers, data = [], []
            for index, (name, value, count, number, rank, position) in enumerate(rows):
                start = index * 3 + 1
                headers += [(_column(start), name), (_column(start + 1), count), (_column(start + 2), rank)]
                data += [(_column(start), 'Ada' if sheet == 'sheet5.xml' else value), (_column(start + 1), number), (_column(start + 2), position)]
        for _, value in headers + data:
            if value not in shared: shared.append(value)
        def xml_row(number, values):
            return f'<row r="{number}">' + ''.join(f'<c r="{column}{number}" t="s"><v>{shared.index(value)}</v></c>' for column, value in values) + '</row>'
        cells.append(xml_row(5, headers)); cells.append(xml_row(6, data))
        with zipfile.ZipFile(path, 'a') as archive:
            archive.writestr(f'xl/worksheets/{sheet}', '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>' + ''.join(cells) + '</sheetData></worksheet>')
    with zipfile.ZipFile(path, 'a') as archive:
        strings = ''.join(f'<si><t>{value}</t></si>' for value in shared)
        archive.writestr('xl/sharedStrings.xml', f'<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">{strings}</sst>')


def _column(number):
    output = ''
    while number:
        number, remainder = divmod(number - 1, 26)
        output = chr(remainder + 65) + output
    return output
