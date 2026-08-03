"""Parser for GfdS's published German annual top-ten first-name lists."""

import html
import re
from pathlib import Path

from .ssa_us import Observation, SourceFormatError


def load_decade(file: Path) -> list[Observation]:
    text = file.read_text(encoding='utf-8')
    output = []
    for year in range(2015, 2025):
        section = re.search(rf'<div id="collapse{year}".*?(?=<div id="collapse|\Z)', text, re.S)
        if not section:
            raise SourceFormatError(f'GfdS page lacks {year}.')
        lists = re.findall(r'<ol>(.*?)</ol>', section.group(), re.S)
        if len(lists) != 2:
            raise SourceFormatError(f'GfdS {year} has no two top-ten lists.')
        for names, category in zip(lists, ('girl', 'boy')):
            values = [html.unescape(re.sub(r'<.*?>', '', value)).strip() for value in re.findall(r'<li>(.*?)</li>', names, re.S)]
            if len(values) != 10 or any(not value for value in values):
                raise SourceFormatError(f'Invalid GfdS {year} {category} list.')
            output.extend(Observation(name, category, year, 0, rank) for rank, name in enumerate(values, 1))
    return output
