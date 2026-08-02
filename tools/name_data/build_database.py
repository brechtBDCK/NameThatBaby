"""Deterministic, offline SQLite builder using committed development fixture rows.

Replace fixture rows with cached official downloads before public distribution.
"""
import hashlib
import json
import sqlite3
import sys
import unicodedata
from pathlib import Path

from adapters.ssa_us import load_decade
from adapters.insee_fr import load_decade as load_insee_decade
from adapters.ine_es import load_decade as load_ine_es_decade

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/data'
COUNTRIES = {'US':'United States','CA':'Canada','BE':'Belgium','NL':'Netherlands','DK':'Denmark','NO':'Norway','SE':'Sweden','DE':'Germany','FR':'France','ES':'Spain','IT':'Italy','AT':'Austria','GB':'United Kingdom','IE':'Ireland','AU':'Australia'}
NAMES = {'girl':['Elena','Nora','Olivia','Sofia','Amélie','Mila','Clara','Lucia','Iris','Ava'], 'boy':['Leo','Noah','Arthur','Oliver','Luca','Hugo','Felix','Milo','Oscar','Theo']}


def insert_observation(conn, name_id, source, name, category, year, count, rank):
    key = ' '.join(unicodedata.normalize('NFC', name).strip().split()).casefold()
    row = conn.execute('SELECT id FROM name WHERE normalized_key=?', (key,)).fetchone()
    if not row:
        conn.execute('INSERT INTO name VALUES (?, ?, ?)', (name_id, name, key))
        row = (name_id,)
        name_id += 1
    conn.execute(
        'INSERT INTO name_observation VALUES (?, ?, ?, ?, ?, ?)',
        (row[0], source, year, category, count, rank),
    )
    return name_id

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
    archive = ROOT / 'tools/name_data/raw_cache/names.zip'
    us_rows = load_decade(archive) if archive.exists() else None
    fr_archive = ROOT / 'tools/name_data/raw_cache/prenoms-2024-nat_csv.zip'
    fr_rows = load_insee_decade(fr_archive) if fr_archive.exists() else None
    es_archive = ROOT / 'tools/name_data/raw_cache/ine_es'
    es_rows = load_ine_es_decade(es_archive) if es_archive.exists() else None
    official_rows = {'US': us_rows, 'FR': fr_rows, 'ES': es_rows}
    official_metadata = {
        'US': ('US-ssa-national-names', 'Social Security Administration', 'https://www.ssa.gov/oact/babynames/limits.html', archive),
        'FR': ('FR-insee-national-names', 'INSEE', 'https://www.insee.fr/fr/statistiques/8894961', fr_archive),
        'ES': ('ES-ine-newborn-names', 'Instituto Nacional de Estadística', 'https://www.ine.es/dyngs/INEbase/es/operacion.htm?c=Estadistica_C&cid=1254736177009&idp=1254735572981&menu=resultados&secc=1254736195453', es_archive / 'nomnac24.xlsx'),
    }
    name_id = 1
    for code in sorted(COUNTRIES):
        source = f'{code}-development-fixture'
        provider = 'Development fixture; official source pending import'
        url = 'See tools/name_data/sources.yaml'
        edition = 'fixture-v1'
        notes = 'Prototype-only sample preserving source schema.'
        rows = official_rows.get(code)
        if rows is not None:
            source, provider, url, raw = official_metadata[code]
            edition = f'{min(row.year for row in rows)}-{max(row.year for row in rows)}'
            notes = f'Official national archive; raw SHA-256 {hashlib.sha256(raw.read_bytes()).hexdigest()}.'
        conn.execute('INSERT INTO data_source VALUES (?, ?, ?, ?, ?, ?, ?, ?)', (source, code, provider, url, edition, '2026-08-02', 'review_before_release', notes))
        if rows is not None:
            for row in rows:
                name_id = insert_observation(conn, name_id, source, row.name, row.category, row.year, row.count, row.rank)
            continue
        for category, values in NAMES.items():
            for rank, name in enumerate(values, 1):
                for year in range(2015, 2025):
                    name_id = insert_observation(conn, name_id, source, name, category, year, 1000-rank, rank)
    conn.commit(); conn.execute('VACUUM'); conn.close()
    sha = hashlib.sha256(database.read_bytes()).hexdigest()
    country_manifest = []
    for code in sorted(COUNTRIES):
        country_rows = official_rows.get(code)
        official = country_rows is not None
        country_manifest.append({
            'code': code,
            'provider': official_metadata[code][1] if official else 'Development fixture; see sources.yaml',
            'covered_years': [min(row.year for row in country_rows), max(row.year for row in country_rows)] if official else [2015, 2024],
            'record_count_per_category': {category: sum(row.category == category for row in country_rows) for category in ('girl', 'boy')} if official else 100,
            'coverage_limitations': 'Raw archive imported; redistribution licensing remains under review.' if official else 'Not production data; import official cached source before release.',
        })
    imported = sorted(code for code, rows in official_rows.items() if rows is not None)
    manifest = {'schema_version': 1, 'generated_at': '2026-08-02T00:00:00Z', 'build_id': f"official-{'-'.join(code.lower() for code in imported)}-plus-fixtures" if imported else 'development-fixture-v1', 'sqlite_sha256': sha, 'redistribution_review_required': True, 'development_fixture_only': not imported, 'contains_fixture_coverage': len(imported) < len(COUNTRIES), 'countries': country_manifest}
    (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')
    print(f'{database} {sha}')

if __name__ == '__main__': build()
