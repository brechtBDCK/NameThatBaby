import hashlib
import json
import sqlite3
import sys
from pathlib import Path

database, manifest_path = map(Path, sys.argv[1:3])
manifest = json.loads(manifest_path.read_text())
conn = sqlite3.connect(database)
assert conn.execute('SELECT count(*) FROM country').fetchone()[0] == 15
assert manifest['schema_version'] == 3
assert manifest['sqlite_sha256'] == hashlib.sha256(database.read_bytes()).hexdigest()
assert conn.execute("SELECT count(*) FROM country_decade_ranking WHERE source_rank < 1").fetchone()[0] == 0
assert conn.execute("SELECT count(*) FROM country_decade_ranking WHERE decade_score <= 0 OR observed_years < 1 OR latest_rank < 1 OR best_rank < 1").fetchone()[0] == 0
assert conn.execute("SELECT count(*) FROM country_decade_ranking WHERE trend NOT IN ('rising', 'falling', 'stable')").fetchone()[0] == 0
assert conn.execute("SELECT count(*) FROM country_decade_ranking WHERE trend IS NOT NULL AND observed_years < 2").fetchone()[0] == 0
assert conn.execute("SELECT count(*) FROM country_decade_ranking WHERE source_id NOT IN (SELECT id FROM data_source)").fetchone()[0] == 0
assert conn.execute("SELECT count(*) FROM name WHERE trim(display_name) = ''").fetchone()[0] == 0
assert conn.execute("SELECT count(*) FROM data_source WHERE country_code NOT IN (SELECT code FROM country)").fetchone()[0] == 0
assert conn.execute("SELECT count(*) FROM country_decade_ranking WHERE country_code NOT IN (SELECT code FROM country)").fetchone()[0] == 0
assert conn.execute("SELECT count(*) FROM country_decade_ranking r JOIN country c ON c.code=r.country_code WHERE c.enabled=0").fetchone()[0] == 0
assert conn.execute("SELECT count(*) FROM data_source s JOIN country c ON c.code=s.country_code WHERE c.enabled=1 AND lower(s.id || ' ' || s.provider) GLOB '*fixture*'").fetchone()[0] == 0
assert conn.execute("SELECT count(*) FROM data_source s JOIN country c ON c.code=s.country_code WHERE c.enabled=1 AND lower(s.id || ' ' || s.provider) GLOB '*template*'").fetchone()[0] == 0
for code, in conn.execute('SELECT code FROM country WHERE enabled=1'):
    for category in ('girl', 'boy'):
        assert conn.execute('SELECT count(DISTINCT name_id) FROM country_decade_ranking WHERE country_code=? AND category=?', (code, category)).fetchone()[0] > 0
assert {item['code'] for item in manifest['countries']} == {
    row[0] for row in conn.execute('SELECT code FROM country')
}
assert manifest['redistribution_review_required'] is True
manifest_countries = {item['code']: item for item in manifest['countries']}
for code, enabled in conn.execute('SELECT code, enabled FROM country'):
    assert manifest_countries[code]['available'] is bool(enabled)
print('database validation passed')
