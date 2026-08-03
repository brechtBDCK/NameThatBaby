"""Parser for Statbel's municipal 2015–2024 newborn-name aggregates."""

import csv
import io
import zipfile
from collections import defaultdict
from pathlib import Path

from .ssa_us import Observation, SourceFormatError


def load_decade(directory: Path) -> list[Observation]:
    output = []
    for archive_name, category in (('male.zip', 'boy'), ('female.zip', 'girl')):
        totals = defaultdict(int)
        with zipfile.ZipFile(directory / archive_name) as archive:
            name = next((item for item in archive.namelist() if item.endswith('.txt')), None)
            if name is None:
                raise SourceFormatError(f'Statbel {category} archive has no text file.')
            for row in csv.DictReader(io.TextIOWrapper(archive.open(name), encoding='cp1252'), delimiter='|'):
                name, count = row.get('TX_FST_NAME', '').strip(), row.get('MS_FREQUENCY', '')
                if name and count.isdigit(): totals[name] += int(count)
        for rank, (name, count) in enumerate(sorted(totals.items(), key=lambda item: (-item[1], item[0].casefold())), 1):
            output.append(Observation(name, category, 2024, count, rank))
    if not output:
        raise SourceFormatError('Statbel aggregate has no name rows.')
    return output
