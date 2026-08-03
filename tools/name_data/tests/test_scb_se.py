import tempfile
import unittest
import zipfile
from pathlib import Path

from tools.name_data.adapters.scb_se import load_decade


class ScbSeAdapterTest(unittest.TestCase):
    def test_reads_annual_rows_and_derives_tied_ranks(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / 'scb.zip'
            later = Path(directory) / 'later'
            with zipfile.ZipFile(archive, 'w') as source:
                rows = ['year,sex,first name normally used,Number of children born']
                for year in range(2015, 2023):
                    rows += [f'{year},boys,Alf,10', f'{year},boys,Ben,10', f'{year},girls,Ada,12']
                source.writestr('names.csv', '\n'.join(rows).encode('cp1252'))
            observations = load_decade(archive)
            later.mkdir()
            _later_workbook(later / '2023.xlsx', 2023)
            _later_workbook(later / '2024.xlsx', 2024)
            complete = load_decade(archive, later)
        self.assertEqual(len(observations), 24)
        self.assertEqual({row.year for row in complete}, set(range(2015, 2025)))
        self.assertEqual([(row.name, row.rank) for row in observations[:2]], [('Alf', 1), ('Ben', 1)])


if __name__ == '__main__':
    unittest.main()


def _later_workbook(path, year):
    strings = []
    sheets = []
    for sheet, category in (('sheet1.xml', 'Girl'), ('sheet2.xml', 'Boy')):
        rows = []
        for rank in range(1, 101):
            values = (('B', str(rank)), ('D', f'{category}{rank}'), ('E', '10')) if year == 2023 and category == 'Girl' else (('A', str(rank)), ('C', f'{category}{rank}'), ('D', '10'))
            for _, value in values:
                if value not in strings: strings.append(value)
            rows.append('<row r="%d">%s</row>' % (rank, ''.join('<c r="%s%d" t="s"><v>%d</v></c>' % (column, rank, strings.index(value)) for column, value in values)))
        sheets.append((sheet, ''.join(rows)))
    with zipfile.ZipFile(path, 'w') as source:
        source.writestr('xl/sharedStrings.xml', '<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">%s</sst>' % ''.join('<si><t>%s</t></si>' % value for value in strings))
        for sheet, rows in sheets:
            source.writestr('xl/worksheets/' + sheet, '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>%s</sheetData></worksheet>' % rows)
