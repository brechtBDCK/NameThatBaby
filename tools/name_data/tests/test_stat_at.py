import tempfile
import unittest
from pathlib import Path

from tools.name_data.adapters.stat_at import load_decade


class StatAtAdapterTest(unittest.TestCase):
    def test_aggregates_district_counts_and_derives_tied_ranks(self):
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory) / 'names.csv'
            _write(file)
            rows = load_decade(file)
        first_boys = [row for row in rows if row.year == 2015 and row.category == 'boy'][:2]
        self.assertEqual([(row.name, row.count, row.rank) for row in first_boys], [('Boy1', 601, 1), ('Boy2', 601, 1)])
        self.assertEqual(len(rows), 10000)


def _write(file):
    lines = ['C-JAHR-0;C-WOHNBEZIRK-0;C-GESCHLECHT-0;F-VORNAME_NORMALISIERT;F-ANZAHL_LGEB']
    for year in range(2015, 2025):
        for category, prefix in (('1', 'Boy'), ('2', 'Girl')):
            for rank in range(1, 501):
                count = 600 if rank in (1, 2) else 501 - rank
                lines.extend((
                    f'{year};101;{category};{prefix}{rank};{count}',
                    f'{year};102;{category};{prefix}{rank};1',
                ))
    file.write_text('\n'.join(lines))


if __name__ == '__main__':
    unittest.main()
