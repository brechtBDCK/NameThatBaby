import tempfile
import unittest
import zipfile
from pathlib import Path

from tools.name_data.adapters.ssa_us import SourceFormatError, load_decade


class SsaAdapterTest(unittest.TestCase):
    def test_parses_ten_year_archive_and_assigns_tied_ranks(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / 'names.zip'
            with zipfile.ZipFile(archive, 'w') as source:
                for year in range(2015, 2025):
                    source.writestr(f'yob{year}.txt', 'Anna,F,10\nBella,F,10\nNoah,M,12\n')
            rows = load_decade(archive)
        self.assertEqual(len(rows), 30)
        self.assertEqual([row.rank for row in rows[:2]], [1, 1])
        self.assertEqual({row.year for row in rows}, set(range(2015, 2025)))

    def test_rejects_incomplete_window(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / 'names.zip'
            with zipfile.ZipFile(archive, 'w') as source:
                source.writestr('yob2024.txt', 'Anna,F,10\n')
            with self.assertRaises(SourceFormatError):
                load_decade(archive)


if __name__ == '__main__':
    unittest.main()
