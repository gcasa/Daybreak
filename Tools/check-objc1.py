#!/usr/bin/env python3
"""Reject Objective-C 2 language features in project-owned source files."""
import pathlib
import re
import sys
bad = []
for directory in ('Source', 'Tests'):
    for path in pathlib.Path(directory).glob('*'):
        if path.suffix not in ('.h', '.m', '.inc'):
            continue
        source = re.sub(r'/\*.*?\*/|//[^\n]*', '', path.read_text(), flags=re.S)
        for pattern in (r'@(property|synthesize|dynamic|autoreleasepool|optional|required)\b',
                        r'@\s*[\[\{\d(]', r'\^\s*\(', r'\b(__weak|__strong|__bridge)\b',
                        r'for\s*\([^;{}]*\bin\b[^;{}]*\)', r'\bid\s*<[^>]*>\s*<'):
            if re.search(pattern, source):
                bad.append(f'{path}: forbidden syntax matching {pattern}')
if bad:
    sys.exit('\n'.join(bad))
print('Objective-C 1.0 syntax guard passed')
