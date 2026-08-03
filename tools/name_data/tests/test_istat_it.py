import tempfile
import unittest
from pathlib import Path
from tools.name_data.adapters.istat_it import load_decade

class IstatAdapterTest(unittest.TestCase):
 def test_reads_ranked_jsonp(self):
  with tempfile.TemporaryDirectory() as d:
   for year in range(2015, 2025):
    rows = [{'name': f'M{n}', 'count': 101-n, 'gender': 'm'} for n in range(1,101)] + [{'name': f'F{n}', 'count': 101-n, 'gender': 'f'} for n in range(1,101)]
    Path(d, f'{year}.jsonp').write_text('callback({"0":' + str(rows[:100]).replace("'", '"') + ',"1":' + str(rows[100:]).replace("'", '"') + '});')
   result = load_decade(Path(d))
  self.assertEqual(len(result), 2000)
  self.assertEqual(result[0].category, 'boy')

