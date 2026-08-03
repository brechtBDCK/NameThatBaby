import tempfile
import unittest
from pathlib import Path

from tools.name_data.adapters.nsw_au import load_decade


class NswAuAdapterTest(unittest.TestCase):
    def test_reads_all_complete_years(self):
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory) / 'names.csv'
            rows = ['Rank,Name,Number,Gender,Year']
            for year in range(2015, 2025):
                rows += [f'1,ALF,10,Male,{year}', f'1,ADA,12,Female,{year}']
            file.write_text('\n'.join(rows))
            result = load_decade(file)
        self.assertEqual(len(result), 20)
        self.assertEqual({row.category for row in result}, {'girl', 'boy'})
