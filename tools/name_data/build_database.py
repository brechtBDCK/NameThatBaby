"""Deterministic, offline SQLite builder using committed development fixture rows.

Replace fixture rows with cached official downloads before public distribution.
"""
import hashlib
import json
import sqlite3
import sys
import unicodedata
import math
from pathlib import Path

from adapters.ssa_us import load_decade
from adapters.insee_fr import load_decade as load_insee_decade
from adapters.ine_es import load_decade as load_ine_es_decade
from adapters.statcan_ca import load_decade as load_statcan_ca_decade
from adapters.ssb_no import load_decade as load_ssb_no_decade
from adapters.dst_dk import load_decade as load_dst_dk_decade
from adapters.cso_ie import load_decade as load_cso_ie_decade
from adapters.stat_at import load_decade as load_stat_at_decade
from adapters.istat_it import load_decade as load_istat_it_decade
from adapters.scb_se import load_decade as load_scb_se_decade
from adapters.uk_gb import load_england_wales, load_northern_ireland, load_scotland
from adapters.nsw_au import load_decade as load_nsw_au_decade
from adapters.qld_au import load_decade as load_qld_au_decade
from adapters.statbel_be import load_decade as load_statbel_be_decade
from adapters.gfds_de import load_decade as load_gfds_de_decade

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets/data'
COUNTRIES = {'US':'United States','CA':'Canada','BE':'Belgium','NL':'Netherlands','DK':'Denmark','NO':'Norway','SE':'Sweden','DE':'Germany','FR':'France','ES':'Spain','IT':'Italy','AT':'Austria','GB':'United Kingdom','IE':'Ireland','AU':'Australia'}
NAMES = {'girl':['Elena','Nora','Olivia','Sofia','Amélie','Mila','Clara','Lucia','Iris','Ava'], 'boy':['Leo','Noah','Arthur','Oliver','Luca','Hugo','Felix','Milo','Oscar','Theo']}


def raw_checksum(path):
    digest = hashlib.sha256()
    for item in (path if isinstance(path, tuple) else (path,)):
        for file in ([item] if item.is_file() else sorted(item.iterdir())):
            digest.update(file.name.encode())
            digest.update(file.read_bytes())
    return digest.hexdigest()


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


def materialize_runtime_rankings(conn):
    """Keep only the small, directly queried candidate rankings at runtime."""
    conn.execute('''CREATE TABLE country_decade_ranking(
      country_code TEXT NOT NULL, category TEXT NOT NULL, name_id INTEGER NOT NULL,
      source_rank INTEGER NOT NULL, PRIMARY KEY(country_code, category, name_id))''')
    for country, in conn.execute('SELECT code FROM country ORDER BY code'):
      for category in ('girl', 'boy'):
        source_lists = {}
        rows = conn.execute('''SELECT o.source_id, o.name_id, n.normalized_key,
              o.year, o.source_rank FROM name_observation o JOIN name n ON n.id=o.name_id
              JOIN data_source s ON s.id=o.source_id
              WHERE s.country_code=? AND o.category=?''', (country, category))
        grouped = {}
        for source, name_id, key, year, rank in rows:
          grouped.setdefault(source, {}).setdefault(name_id, [key, []])[1].append((year, rank))
        for source, names in grouped.items():
          ranked = []
          for name_id, (key, observations) in names.items():
            score = sum(1 / math.log2(rank + 1) for _, rank in observations)
            years = len({year for year, _ in observations})
            latest_year = max(year for year, _ in observations)
            latest_rank = min(rank for year, rank in observations if year == latest_year)
            best_rank = min(rank for _, rank in observations)
            ranked.append((name_id, key, score, years, latest_rank, best_rank))
          ranked.sort(key=lambda row: (-row[2], -row[3], row[4], row[5], row[1]))
          source_lists[source] = ranked
        positions = {source: 0 for source in source_lists}
        seen, selected = set(), []
        while True:
          progressed = False
          for source in sorted(source_lists):
            items = source_lists[source]
            while positions[source] < len(items):
              item = items[positions[source]]
              positions[source] += 1
              if item[1] not in seen:
                seen.add(item[1]); selected.append(item[0]); progressed = True; break
          if len(selected) >= 150: break
          if not progressed: break
        conn.executemany('INSERT INTO country_decade_ranking VALUES (?, ?, ?, ?)',
                         [(country, category, name_id, rank) for rank, name_id in enumerate(selected, 1)])
    conn.execute('DELETE FROM name WHERE id NOT IN (SELECT name_id FROM country_decade_ranking)')
    conn.execute('DROP TABLE name_observation')

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
    ''')
    conn.executemany('INSERT INTO country VALUES (?, ?, 1)', sorted(COUNTRIES.items()))
    archive = ROOT / 'tools/name_data/raw_cache/names.zip'
    us_rows = load_decade(archive) if archive.exists() else None
    fr_archive = ROOT / 'tools/name_data/raw_cache/prenoms-2024-nat_csv.zip'
    fr_rows = load_insee_decade(fr_archive) if fr_archive.exists() else None
    es_archive = ROOT / 'tools/name_data/raw_cache/ine_es'
    es_rows = load_ine_es_decade(es_archive) if es_archive.exists() else None
    ca_archive = ROOT / 'tools/name_data/raw_cache/statcan_ca/17100147-eng.zip'
    ca_rows = load_statcan_ca_decade(ca_archive) if ca_archive.exists() else None
    no_archive = ROOT / 'tools/name_data/raw_cache/ssb_no/fornavn_fodte_2015_2024.json'
    no_rows = load_ssb_no_decade(no_archive) if no_archive.exists() else None
    dk_archive = ROOT / 'tools/name_data/raw_cache/dst_dk'
    dk_rows = load_dst_dk_decade(dk_archive) if dk_archive.exists() else None
    ie_archive = ROOT / 'tools/name_data/raw_cache/cso_ie'
    ie_rows = load_cso_ie_decade(ie_archive) if ie_archive.exists() else None
    at_archive = ROOT / 'tools/name_data/raw_cache/stat_at/OGDEXT_VORNAMEN_1.csv'
    at_rows = load_stat_at_decade(at_archive) if at_archive.exists() else None
    it_archive = ROOT / 'tools/name_data/raw_cache/istat_it'
    it_rows = load_istat_it_decade(it_archive) if it_archive.exists() else None
    se_archive = ROOT / 'tools/name_data/raw_cache/scb_se/TAB5665_en.zip'
    se_later_years = ROOT / 'tools/name_data/raw_cache/isof_se'
    se_rows = load_scb_se_decade(se_archive, se_later_years) if se_archive.exists() and se_later_years.exists() else (load_scb_se_decade(se_archive) if se_archive.exists() else None)
    ons_archive = ROOT / 'tools/name_data/raw_cache/ons_ew/babynames1996to2024.xlsx'
    nrs_archive = ROOT / 'tools/name_data/raw_cache/nrs_scotland/full-list-1974-2024.zip'
    nisra_archive = ROOT / 'tools/name_data/raw_cache/nisra_ni/full-name-list-1997-2024.xlsx'
    nsw_archive = ROOT / 'tools/name_data/raw_cache/nsw_au/names.csv'
    au_rows = load_nsw_au_decade(nsw_archive) if nsw_archive.exists() else None
    qld_archive = ROOT / 'tools/name_data/raw_cache/qld_au'
    qld_rows = load_qld_au_decade(qld_archive) if all((qld_archive / f'{year}.json').exists() for year in range(2015, 2025)) else None
    be_archive = ROOT / 'tools/name_data/raw_cache/statbel_be'
    be_rows = load_statbel_be_decade(be_archive) if all((be_archive / name).exists() for name in ('male.zip', 'female.zip')) else None
    de_archive = ROOT / 'tools/name_data/raw_cache/gfds_de/first-name-rankings.html'
    de_rows = load_gfds_de_decade(de_archive) if de_archive.exists() else None
    gb_rows = (
        [
            ('GB-ons-england-wales', load_england_wales(ons_archive), 'Office for National Statistics', 'https://www.ons.gov.uk/peoplepopulationandcommunity/birthsdeathsandmarriages/livebirths/datasets/babynamesinenglandandwalesfrom1996/1996to2024', ons_archive),
            ('GB-nrs-scotland', load_scotland(nrs_archive), 'National Records of Scotland', 'https://www.nrscotland.gov.uk/publications/babies-first-names-2024/', nrs_archive),
            ('GB-nisra-northern-ireland', load_northern_ireland(nisra_archive), 'Northern Ireland Statistics and Research Agency', 'https://www.nisra.gov.uk/publications/baby-names-2024', nisra_archive),
        ] if all(item.exists() for item in (ons_archive, nrs_archive, nisra_archive)) else None
    )
    official_sources = {
        'US': [('US-ssa-national-names', us_rows, 'Social Security Administration', 'https://www.ssa.gov/oact/babynames/limits.html', archive)],
        'CA': [('CA-statcan-first-names', ca_rows, 'Statistics Canada', 'https://www150.statcan.gc.ca/t1/tbl1/en/tv.action?pid=1710014701', ca_archive)],
        'AT': [('AT-statistics-austria-first-names', at_rows, 'Statistics Austria', 'https://data.statistik.gv.at/data/OGDEXT_VORNAMEN_1.csv', at_archive)],
        'DK': [('DK-dst-newborn-names', dk_rows, 'Statistics Denmark', 'https://www.dst.dk/en/Statistik/emner/borgere/navne/navne-til-nyfoedte', dk_archive)],
        'IE': [('IE-cso-newborn-names', ie_rows, 'Central Statistics Office Ireland', 'https://ws.cso.ie/public/api.restful/PxStat.Data.Cube_API.ReadDataset/VSA50/CSV/1.0/en', ie_archive)],
        'IT': [('IT-istat-newborn-names', it_rows, 'ISTAT', 'https://www.istat.it/dati/calcolatori/contanomi/', it_archive)],
        'SE': [('SE-scb-newborn-names', se_rows, 'Statistics Sweden and Institute for Language and Folklore', 'https://www.statistikdatabasen.scb.se/pxweb/en/ssd/START__BE__BE0001__BE0001D/BE0001Nyfodda/', (se_archive, se_later_years))],
        'NO': [('NO-ssb-born-names', no_rows, 'Statistics Norway', 'https://data.ssb.no/api/v0/en/table/FornavnFodte', no_archive)],
        'FR': [('FR-insee-national-names', fr_rows, 'INSEE', 'https://www.insee.fr/fr/statistiques/8894961', fr_archive)],
        'ES': [('ES-ine-newborn-names', es_rows, 'Instituto Nacional de Estadística', 'https://www.ine.es/dyngs/INEbase/es/operacion.htm?c=Estadistica_C&cid=1254736177009&idp=1254735572981&menu=resultados&secc=1254736195453', es_archive / 'nomnac24.xlsx')],
        'AU': [
            ('AU-nsw-baby-names', au_rows, 'New South Wales Registry of Births, Deaths and Marriages', 'https://data.nsw.gov.au/data/dataset/popular-baby-names-from-1952', nsw_archive),
            ('AU-qld-baby-names', qld_rows, 'Queensland Registry of Births, Deaths and Marriages', 'https://www.data.qld.gov.au/dataset/top-100-baby-names', qld_archive),
        ],
        'BE': [('BE-statbel-newborn-names', be_rows, 'Statbel', 'https://statbel.fgov.be/en/open-data', be_archive)],
        'DE': [('DE-gfds-first-names', de_rows, 'Gesellschaft für deutsche Sprache', 'https://gfds.de/vornamen/beliebteste-vornamen/', de_archive)],
    }
    if gb_rows: official_sources['GB'] = gb_rows
    official_sources = {code: [entry for entry in entries if entry[1] is not None] for code, entries in official_sources.items()}
    name_id = 1
    for code in sorted(COUNTRIES):
        source = f'{code}-development-fixture'
        provider = 'Development fixture; official source pending import'
        url = 'See tools/name_data/sources.yaml'
        edition = 'fixture-v1'
        notes = 'Prototype-only sample preserving source schema.'
        sources = official_sources.get(code, [])
        if sources:
            for source, rows, provider, url, raw in sources:
                edition = f'{min(row.year for row in rows)}-{max(row.year for row in rows)}'
                notes = f'Official archive; raw SHA-256 {raw_checksum(raw)}.'
                conn.execute('INSERT INTO data_source VALUES (?, ?, ?, ?, ?, ?, ?, ?)', (source, code, provider, url, edition, '2026-08-03', 'review_before_release', notes))
                for row in rows:
                    name_id = insert_observation(conn, name_id, source, row.name, row.category, row.year, row.count, row.rank)
            continue
        conn.execute('INSERT INTO data_source VALUES (?, ?, ?, ?, ?, ?, ?, ?)', (source, code, provider, url, edition, '2026-08-02', 'review_before_release', notes))
        for category, values in NAMES.items():
            for rank, name in enumerate(values, 1):
                for year in range(2015, 2025):
                    name_id = insert_observation(conn, name_id, source, name, category, year, 1000-rank, rank)
    materialize_runtime_rankings(conn)
    conn.commit(); conn.execute('VACUUM'); conn.close()
    sha = hashlib.sha256(database.read_bytes()).hexdigest()
    country_manifest = []
    for code in sorted(COUNTRIES):
        sources = official_sources.get(code, [])
        country_rows = [row for _, rows, _, _, _ in sources for row in rows]
        official = bool(sources)
        country_manifest.append({
            'code': code,
            'provider': ', '.join(item[2] for item in sources) if official else 'Development fixture; see sources.yaml',
            'covered_years': [min(row.year for row in country_rows), max(row.year for row in country_rows)] if official else [2015, 2024],
            'record_count_per_category': {category: sum(row.category == category for row in country_rows) for category in ('girl', 'boy')} if official else 100,
            'coverage_limitations': ('Equal constituent coverage from England/Wales, Scotland, and Northern Ireland; redistribution licensing remains under review.' if code == 'GB' else 'NSW and Queensland coverage only; add other state and territory sources before national release.' if code == 'AU' else 'One national 2015-2024 aggregate; annual source rows are not published.' if code == 'BE' else 'GfdS national fallback; public top-ten lists only.' if code == 'DE' else 'Raw archive imported; redistribution licensing remains under review.') if official else 'Not production data; import official cached source before release.',
        })
    imported = sorted(code for code, sources in official_sources.items() if sources)
    manifest = {'schema_version': 1, 'generated_at': '2026-08-02T00:00:00Z', 'build_id': f"official-{'-'.join(code.lower() for code in imported)}-plus-fixtures" if imported else 'development-fixture-v1', 'sqlite_sha256': sha, 'redistribution_review_required': True, 'development_fixture_only': not imported, 'contains_fixture_coverage': len(imported) < len(COUNTRIES), 'countries': country_manifest}
    (OUT / 'manifest.json').write_text(json.dumps(manifest, indent=2, sort_keys=True) + '\n')
    print(f'{database} {sha}')

if __name__ == '__main__':
    if len(sys.argv) == 3 and sys.argv[1] == '--output':
        OUT = Path(sys.argv[2])
    elif len(sys.argv) != 1:
        raise SystemExit('usage: build_database.py [--output DIRECTORY]')
    build()
