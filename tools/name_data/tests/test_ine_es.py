import tempfile
import unittest
import zipfile
from pathlib import Path

from tools.name_data.adapters.ine_es import load_decade


class IneAdapterTest(unittest.TestCase):
    def test_parses_national_rows_and_tied_ranks(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            for year in range(15, 25):
                _workbook(folder / f'nomnac{year}.xlsx')
            observations = load_decade(folder)
        self.assertEqual(len(observations), 40)
        self.assertEqual([row.rank for row in observations[:2]], [1, 1])
        self.assertEqual({row.category for row in observations}, {'boy', 'girl'})


def _workbook(path: Path):
    shared = ['TOTAL', 'ALVARO', 'BRUNO', 'SOFIA', 'LUCIA']
    strings = ''.join(f'<si><t>{value}</t></si>' for value in shared)
    rows = '''<row r="4"><c r="A4" t="s"><v>0</v></c><c r="D4" t="s"><v>0</v></c></row>
<row r="5"><c r="A5" t="s"><v>1</v></c><c r="B5"><v>10</v></c><c r="D5" t="s"><v>3</v></c><c r="E5"><v>12</v></c></row>
<row r="6"><c r="A6" t="s"><v>2</v></c><c r="B6"><v>10</v></c><c r="D6" t="s"><v>4</v></c><c r="E6"><v>9</v></c></row>'''
    with zipfile.ZipFile(path, 'w') as archive:
        archive.writestr('xl/sharedStrings.xml', f'<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main">{strings}</sst>')
        archive.writestr('xl/worksheets/sheet2.xml', f'<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>{rows}</sheetData></worksheet>')


if __name__ == '__main__':
    unittest.main()
