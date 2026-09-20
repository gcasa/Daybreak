#!/usr/bin/env python3
"""GNU brace layout plus GNUstep's spaced Objective-C selectors."""
import pathlib
import re
import subprocess
import sys
formatter = sys.argv[1] if len(sys.argv) > 1 else 'clang-format'
files = sorted(p for directory in ('Source', 'Tests') for p in pathlib.Path(directory).iterdir() if p.suffix in ('.h', '.m'))
subprocess.run([formatter, '-i', *map(str, files)], check=True)
for path in files:
    text = path.read_text()
    # Protect comments and string literals while restoring selector spacing.
    pieces = re.split(r'(/\*.*?\*/|//[^\n]*|@?"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\')', text, flags=re.S)
    for index in range(0, len(pieces), 2):
        code = re.sub(r'^([+-] \([^\n)]*\))(?=\w)', r'\1 ', pieces[index], flags=re.M)
        code = re.sub(r'(\b\w+):(?=\S|$)', r'\1: ', code)
        pieces[index] = code
    path.write_text(''.join(pieces))
