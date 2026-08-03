import tempfile
import unittest
import zipfile
from pathlib import Path

from tools.name_data.adapters.statcan_ca import load_decade


class StatcanAdapterTest(unittest.TestCase):
    def test_parses_official_frequency_and_rank(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / 'names.zip'
            with zipfile.ZipFile(archive, 'w') as source:
                source.writestr('17100147.csv', _csv())
            observations = load_decade(archive)
        self.assertEqual(len(observations), 40)
        ava = next(row for row in observations if row.year == 2015 and row.name == 'Ava')
        self.assertEqual(ava.category, 'girl')
        self.assertEqual(ava.count, 12)
        self.assertEqual(ava.rank, 1)


def _csv():
    header = 'REF_DATE,Sex at birth,First name at birth,Indicator,VALUE\n'
    rows = []
    for year in range(2015, 2025):
        rows.extend([
            f'{year},Female,Ava,Frequency,12', f'{year},Female,Ava,Rank,1',
            f'{year},Female,Bea,Frequency,8', f'{year},Female,Bea,Rank,2',
            f'{year},Male,Liam,Frequency,13', f'{year},Male,Liam,Rank,1',
            f'{year},Male,Noah,Frequency,7', f'{year},Male,Noah,Rank,2',
        ])
    return header + '\n'.join(rows)


if __name__ == '__main__':
    unittest.main()
