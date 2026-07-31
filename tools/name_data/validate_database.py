import json, sqlite3, sys
from pathlib import Path

database, manifest_path = map(Path, sys.argv[1:3])
manifest = json.loads(manifest_path.read_text())
conn = sqlite3.connect(database)
assert conn.execute('SELECT count(*) FROM country').fetchone()[0] == 15
assert conn.execute("SELECT count(*) FROM name_observation WHERE source_rank < 1 OR year < 1900").fetchone()[0] == 0
assert conn.execute("SELECT count(*) FROM name WHERE trim(display_name) = ''").fetchone()[0] == 0
assert manifest['redistribution_review_required'] is True
print('database validation passed')
