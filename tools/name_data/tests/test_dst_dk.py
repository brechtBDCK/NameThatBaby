import tempfile
import unittest
from pathlib import Path

from tools.name_data.adapters.dst_dk import load_decade


class DstAdapterTest(unittest.TestCase):
    def test_reads_two_ranked_top_50_tables_per_year(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory)
            for year in range(2015, 2025):
                path.joinpath(f'{year}.html').write_text(_page())
            rows = load_decade(path)
        self.assertEqual(len(rows), 1000)
        self.assertEqual(rows[0].name, 'Anne')
        self.assertEqual(rows[0].category, 'girl')
        self.assertEqual(rows[-1].name, 'Bo')
        self.assertEqual(rows[-1].category, 'boy')


def _page():
    def table(caption, name):
        return '<table><caption>' + caption + '</caption>' + ''.join(
            f'<tr><td>{rank}</td><td>{name}</td><td>{100 - rank}</td><td>1</td></tr>'
            for rank in range(1, 51)
        ) + '</table>'
    return table('Pigenavne', 'Anne') + table('Drengenavne', 'Bo')


if __name__ == '__main__':
    unittest.main()
