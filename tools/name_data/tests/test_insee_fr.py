import tempfile
import unittest
import zipfile
from pathlib import Path

from tools.name_data.adapters.insee_fr import load_decade


class InseeAdapterTest(unittest.TestCase):
    def test_parses_national_rows_and_tied_ranks(self):
        with tempfile.TemporaryDirectory() as directory:
            archive = Path(directory) / 'insee.zip'
            with zipfile.ZipFile(archive, 'w') as source:
                rows = ['sexe;prenom;periode;valeur']
                for year in range(2015, 2025):
                    rows += [f'2;Anna;{year};10', f'2;Bella;{year};10', f'1;Noah;{year};12']
                source.writestr('prenoms.csv', '\n'.join(rows))
            observations = load_decade(archive)
        self.assertEqual(len(observations), 30)
        self.assertEqual([row.rank for row in observations[:2]], [1, 1])


if __name__ == '__main__':
    unittest.main()
