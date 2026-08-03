import json
import tempfile
import unittest
from pathlib import Path

from tools.name_data.adapters.qld_au import load_decade


class QldAuAdapterTest(unittest.TestCase):
    def test_reads_both_ranked_lists_for_each_year(self):
        with tempfile.TemporaryDirectory() as directory:
            folder = Path(directory)
            for year in range(2015, 2025):
                rows = [{'Girl Names': f'Ada{rank}', 'Count of Girl Names': 101-rank, 'Boy Names': f'Alf{rank}', 'Count of Boy Names': 101-rank} for rank in range(1, 101)]
                (folder / f'{year}.json').write_text(json.dumps({'result': {'records': rows}}))
            result = load_decade(folder)
        self.assertEqual(len(result), 2000)
