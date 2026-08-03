import tempfile
import unittest
import zipfile
from pathlib import Path

from tools.name_data.adapters.statbel_be import load_decade


class StatbelBeAdapterTest(unittest.TestCase):
    def test_aggregates_municipal_counts(self):
        with tempfile.TemporaryDirectory() as directory:
            for archive, name in (('male.zip', 'Noah'), ('female.zip', 'Emma')):
                with zipfile.ZipFile(Path(directory) / archive, 'w') as source:
                    source.writestr('names.txt', 'CD_REFNIS|TX_FST_NAME|MS_FREQUENCY\n1|%s|5\n2|%s|6' % (name, name))
            result = load_decade(Path(directory))
        self.assertEqual([(row.name, row.count) for row in result], [('Noah', 11), ('Emma', 11)])
