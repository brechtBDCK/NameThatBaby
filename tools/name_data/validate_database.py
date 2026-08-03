import hashlib
import json
import sqlite3
import sys
from pathlib import Path

database, manifest_path = map(Path, sys.argv[1:3])
manifest = json.loads(manifest_path.read_text())
conn = sqlite3.connect(database)
assert conn.execute('SELECT count(*) FROM country').fetchone()[0] == 15
assert manifest['schema_version'] == 1
assert manifest['sqlite_sha256'] == hashlib.sha256(database.read_bytes()).hexdigest()
assert conn.execute("SELECT count(*) FROM country_decade_ranking WHERE source_rank < 1").fetchone()[0] == 0
assert conn.execute("SELECT count(*) FROM name WHERE trim(display_name) = ''").fetchone()[0] == 0
assert conn.execute("SELECT count(*) FROM data_source WHERE country_code NOT IN (SELECT code FROM country)").fetchone()[0] == 0
assert conn.execute("SELECT count(*) FROM country_decade_ranking WHERE country_code NOT IN (SELECT code FROM country)").fetchone()[0] == 0
assert {item['code'] for item in manifest['countries']} == {
    row[0] for row in conn.execute('SELECT code FROM country')
}
assert manifest['redistribution_review_required'] is True
print('database validation passed')
