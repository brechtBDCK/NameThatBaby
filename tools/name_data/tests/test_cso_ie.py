import tempfile
import unittest
from pathlib import Path

from tools.name_data.adapters.cso_ie import load_decade


class CsoAdapterTest(unittest.TestCase):
    def test_reads_published_counts_and_ranks(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            _write(path / 'VSA50.csv', 'Boys Names')
            _write(path / 'VSA60.csv', 'Girls Names')
            rows = load_decade(path)
        self.assertEqual(len(rows), 10000)
        self.assertEqual(rows[0].category, 'boy')
        self.assertEqual(rows[0].count, 100)
        self.assertEqual(rows[-1].category, 'girl')
        self.assertEqual(rows[-1].rank, 500)


def _write(file, column):
    lines = [f'STATISTIC,Statistic Label,TLIST(A1),Year,CODE,{column},UNIT,VALUE']
    for year in range(2015, 2025):
        for rank in range(1, 501):
            name = f'Name{rank}'
            lines.append(f'TESTC01,Count,{year},{year},{rank:04},{name},Number,{101 - rank % 100}')
            lines.append(f'TESTC02,Rank,{year},{year},{rank:04},{name},Number,{rank}')
    file.write_text('\n'.join(lines))


if __name__ == '__main__':
    unittest.main()
