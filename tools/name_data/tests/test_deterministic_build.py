import hashlib
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[3]
BUILDER = ROOT / 'tools' / 'name_data' / 'build_database.py'


class DeterministicBuildTest(unittest.TestCase):
    def test_same_cached_inputs_produce_the_same_sqlite_checksum(self):
        with tempfile.TemporaryDirectory() as temporary:
            first = Path(temporary) / 'first'
            second = Path(temporary) / 'second'
            for output in (first, second):
                subprocess.run(
                    [sys.executable, str(BUILDER), '--output', str(output)],
                    cwd=ROOT,
                    check=True,
                    capture_output=True,
                    text=True,
                )
            self.assertEqual(
                hashlib.sha256((first / 'names.sqlite').read_bytes()).digest(),
                hashlib.sha256((second / 'names.sqlite').read_bytes()).digest(),
            )


if __name__ == '__main__':
    unittest.main()
