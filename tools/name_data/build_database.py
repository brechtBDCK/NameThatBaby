"""Deterministic, offline SQLite builder using committed development fixture rows.

Replace fixture rows with cached official downloads before public distribution.
"""
import hashlib
import json
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/data'
COUNTRIES = {'US':'United States','CA':'Canada','BE':'Belgium','NL':'Netherlands','DK':'Denmark','NO':'Norway','SE':'Sweden','DE':'Germany','FR':'France','ES':'Spain','IT':'Italy','AT':'Austria','GB':'United Kingdom','IE':'Ireland','AU':'Australia'}
NAMES = {'girl':['Elena','Nora','Olivia','Sofia','Amélie','Mila','Clara','Lucia','Iris','Ava'], 'boy':['Leo','Noah','Arthur','Oliver','Luca','Hugo','Felix','Milo','Oscar','Theo']}

def build():
    OUT.mkdir(parents=True, exist_ok=True)
    database = OUT / 'names.sqlite'
    if database.exists(): database.unlink()
    conn = sqlite3.connect(database)
    conn.executescript('''
      PRAGMA page_size=4096; PRAGMA journal_mode=OFF; PRAGMA synchronous=OFF;
      CREATE TABLE country(code TEXT PRIMARY KEY, display_name TEXT NOT NULL, enabled INTEGER NOT NULL);
      CREATE TABLE data_source(id TEXT PRIMARY KEY, country_code TEXT NOT NULL, provider TEXT NOT NULL, source_url TEXT NOT NULL, edition TEXT NOT NULL, retrieved_at TEXT NOT NULL, license_status TEXT NOT NULL, methodology_notes TEXT);
      CREATE TABLE name(id INTEGER PRIMARY KEY, display_name TEXT NOT NULL, normalized_key TEXT NOT NULL UNIQUE);
      CREATE TABLE name_observation(name_id INTEGER NOT NULL, source_id TEXT NOT NULL, year INTEGER NOT NULL, category TEXT NOT NULL CHECK(category IN ('girl','boy')), count INTEGER, source_rank INTEGER NOT NULL, PRIMARY KEY(name_id,source_id,year,category));
      CREATE INDEX observation_lookup ON name_observation(category, source_id, year, source_rank);
    ''')
    conn.executemany('INSERT INTO country VALUES (?, ?, 1)', sorted(COUNTRIES.items()))
    name_id = 1
    for code in sorted(COUNTRIES):
        source = f'{code}-development-fixture'
        conn.execute('INSERT INTO data_source VALUES (?, ?, ?, ?, ?, ?, ?, ?)', (source, code, 'Development fixture; official source pending import', 'See tools/name_data/sources.yaml', 'fixture-v1', '2026-07-31', 'review_before_release', 'Prototype-only sample preserving source schema.'))
        for category, values in NAMES.items():
            for rank, name in enumerate(values, 1):
                key = name.casefold()
                row = conn.execute('SELECT id FROM name WHERE normalized_key=?', (key,)).fetchone()
                if not row:
                    conn.execute('INSERT INTO name VALUES (?, ?, ?)', (name_id, name, key)); row = (name_id,); name_id += 1
                for year in range(2015, 2025): conn.execute('INSERT INTO name_observation VALUES (?, ?, ?, ?, ?, ?)', (row[0], source, year, category, 1000-rank, rank))
    conn.commit(); conn.execute('VACUUM'); conn.close()
    sha = hashlib.sha256(database.read_bytes()).hexdigest()
    manifest = {'schema_version': 1, 'generated_at': '2026-07-31T00:00:00Z', 'build_id': 'development-fixture-v1', 'sqlite_sha256': sha, 'redistribution_review_required': True, 'development_fixture_only': True, 'countries': [{'code': code, 'provider': 'Development fixture; see sources.yaml', 'covered_years': [2015, 2024], 'record_count_per_category': 100, 'coverage_limitations': 'Not production data; import official cached source before release.'} for code in sorted(COUNTRIES)]}
    (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')
    print(f'{database} {sha}')

if __name__ == '__main__': build()
