import sqlite3
import unittest
from pathlib import Path


DATABASE = Path(__file__).resolve().parents[3] / 'assets' / 'data' / 'names.sqlite'


class MaterializedMetadataTest(unittest.TestCase):
    def test_runtime_rows_keep_compact_popularity_metadata(self):
        with sqlite3.connect(DATABASE) as connection:
            columns = {
                row[1] for row in connection.execute('PRAGMA table_info(country_decade_ranking)')
            }
            self.assertTrue({
                'decade_score', 'observed_years', 'latest_observed_year',
                'latest_rank', 'best_rank', 'source_id', 'trend',
            }.issubset(columns))
            self.assertEqual(
                0,
                connection.execute(
                    "SELECT count(*) FROM country_decade_ranking WHERE country_code='BE' AND trend IS NOT NULL"
                ).fetchone()[0],
            )
            self.assertGreater(
                connection.execute(
                    "SELECT count(*) FROM country_decade_ranking WHERE country_code='FR' AND trend IS NOT NULL"
                ).fetchone()[0],
                0,
            )
            self.assertEqual(
                0,
                connection.execute(
                    "SELECT count(*) FROM sqlite_master WHERE type='table' AND name='name_observation'"
                ).fetchone()[0],
            )


if __name__ == '__main__':
    unittest.main()
