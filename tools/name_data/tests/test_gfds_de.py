import tempfile
import unittest
from pathlib import Path

from tools.name_data.adapters.gfds_de import load_decade


class GfdsDeAdapterTest(unittest.TestCase):
    def test_parses_both_top_tens(self):
        with tempfile.TemporaryDirectory() as directory:
            file = Path(directory) / 'names.html'
            blocks = []
            for year in range(2015, 2025):
                lists = ''.join('<ol>%s</ol>' % ''.join('<li>%s%d</li>' % (prefix, rank) for rank in range(1, 11)) for prefix in ('Girl', 'Boy'))
                blocks.append('<div id="collapse%d">%s</div>' % (year, lists))
            file.write_text(''.join(blocks))
            result = load_decade(file)
        self.assertEqual(len(result), 200)
