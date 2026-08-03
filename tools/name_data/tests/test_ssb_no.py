import json
import tempfile
import unittest
from pathlib import Path

from tools.name_data.adapters.ssb_no import load_decade


class SsbAdapterTest(unittest.TestCase):
    def test_preserves_gender_codes_and_derives_tied_ranks(self):
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory) / 'names.json'
            file.write_text(json.dumps(_data()))
            rows = load_decade(file)
        self.assertEqual(len(rows), 40)
        self.assertEqual([(row.name, row.category, row.rank) for row in rows[:2]], [
            ('Alex', 'girl', 1), ('Bea', 'girl', 1),
        ])


def _data():
    years = [str(year) for year in range(2015, 2025)]
    names = {'1ALEX': 'Alex', '1BEA': 'Bea', '2ALEX': 'Alex', '2BO': 'Bo'}
    return {
        'id': ['Fornavn', 'ContentsCode', 'Tid'], 'size': [4, 1, 10],
        'dimension': {
            'Fornavn': {'category': {'label': names}},
            'Tid': {'category': {'label': {year: year for year in years}}},
        },
        'value': [10] * 10 + [10] * 10 + [12] * 10 + [8] * 10,
    }


if __name__ == '__main__':
    unittest.main()
