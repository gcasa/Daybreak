#!/usr/bin/env python3
"""Reproduce the straight-line opcode port from a local Dwarf checkout.

The generated Objective-C is checked in; Python and Java are not build/runtime
requirements. Complex machine services are deliberately excluded, never stubbed.
Usage: python3 Tools/port-instructions.py ../dwarf
"""
import pathlib
import re
import sys

root = pathlib.Path(__file__).resolve().parents[1]
reference = pathlib.Path(sys.argv[1]) / 'src/dev/hawala/dmachine/engine/opcodes'
ops = []
for chapter in ('Ch03_Memory_Organization', 'Ch05_Stack_Instructions', 'Ch06_Jump_Instructions', 'Ch07_Assignment_Instructions'):
    source = (reference / (chapter + '.java')).read_text()
    source = re.sub(r'/\*.*?\*/|//[^\n]*', '', source, flags=re.S)
    for match in re.finditer(r'public static final OpImpl ((OPC[on]?|ESC)_x([0-9A-F]{2})_\w+) = \(\) -> \{(.*?)\n\s*\};', source, re.S):
        name, kind, code, body = match.groups()
        if name.endswith('RestoreAfterFloatOp') or 'signalEscOpcodeTrap' in body:
            continue
        if chapter.startswith('Ch03'):
            allowed = {'SM', 'GMF', 'SMF', 'LP', 'ROB', 'WOB', 'RRMDS', 'WRMDS'}
            if name.split('_')[2] not in allowed:
                continue
            body = re.sub(r'Cpu.logf\([^;]*;', '', body)
            body = body.replace('" + alpha', '"')
            body = body.replace('Cpu.pop() << PrincOpsDefs.WORD_BITS', '(uint32_t)(uint16_t)Cpu.pop() << 16')
            body = body.replace('PrincOpsDefs.WORD_BITS', '16')
        ops.append((name, kind, int(code, 16), body, chapter))

selectors = {
 'Mem.setMap': ('_memory', ['mapPage', 'to', 'flags']),
 'Mem.getVPageFlags': ('_memory', ['flagsForPage']),
 'Mem.getVPageRealPage': ('_memory', ['realPageForPage']),
 'Mem.isVacant': ('DBMemory', ['isVacant']),
 'Cpu.push': ('self', ['push']), 'Cpu.pop': ('self', ['pop']),
 'Cpu.pushLong': ('self', ['pushLong']), 'Cpu.popLong': ('self', ['popLong']),
 'Cpu.popRecover': ('self', ['popRecover']), 'Cpu.recover': ('self', ['recover']),
 'Cpu.discard': ('self', ['discard']), 'Cpu.lengthenPointer': ('self', ['lengthenPointer']),
 'Cpu.boundsTrap': ('self', ['boundsTrap']), 'Cpu.pointerTrap': ('self', ['pointerTrap']),
 'Cpu.divZeroTrap': ('self', ['divZeroTrap']), 'Cpu.divCheckTrap': ('self', ['divCheckTrap']),
 'Cpu.ERROR': ('self', ['hardwareError']),
 'Mem.getNextCodeByte': ('self', ['nextCodeByte']),
 'Mem.getNextCodeWord': ('self', ['nextCodeWord']),
 'Mem.readCode': ('self', ['readCode']),
 'Mem.readMDSWord': ('self', ['readMDSWord', 'offset']),
 'Mem.readMDSDblWord': ('self', ['readMDSDoubleWord', 'offset']),
 'Mem.readWord': ('_memory', ['readWord']),
 'Mem.readDblWord': ('_memory', ['readDoubleWord']),
 'Mem.writeWord': ('_memory', ['writeWord', 'value']),
 'Mem.fetchByte': ('_memory', ['fetchByte', 'offset']),
 'Mem.storeByte': ('_memory', ['storeByte', 'offset', 'value']),
 'Mem.readField': ('DBMemory', ['fieldFromWord', 'specification']),
 'Mem.writeField': ('DBMemory', ['word', 'specification', 'withField']),
 'popFloat': ('self', ['popFloat']), 'pushFloat': ('self', ['pushFloat'])}

def convert_calls(body):
    pattern = r'\b(' + '|'.join(re.escape(k) for k in selectors) + r'|Mem\.writeMDSWord|(?:OPC[on]?|ESC)_x[0-9A-F]{2}_\w+\.execute)\('
    while (match := re.search(pattern, body)):
        depth, pos, start, args = 1, match.end(), match.end(), []
        while depth:
            c = body[pos]
            if c == '(': depth += 1
            elif c == ')': depth -= 1
            if (c == ',' and depth == 1) or depth == 0:
                if body[start:pos].strip(): args.append(convert_calls(body[start:pos].strip()))
                start = pos + 1
            pos += 1
        key = match.group(1)
        if key == 'Mem.setMap': args = args[1:]
        if key == 'Mem.writeMDSWord':
            receiver, labels = 'self', ['writeMDSWord', 'value'] if len(args) == 2 else ['writeMDSWord', 'offset', 'value']
        elif key.endswith('.execute'):
            receiver, labels = 'self', [key[:-8]]
        else: receiver, labels = selectors[key]
        call = '[' + receiver + ' ' + (' '.join(k + ': ' + a for k, a in zip(labels, args)) if args else labels[0]) + ']'
        if key in ('Mem.readWord', 'Mem.readMDSWord', 'Mem.readCode', 'Mem.readField'):
            call = '(int16_t)' + call
        body = body[:match.start()] + call + body[pos:]
    return body

text = ['/* Derived from Dwarf by Dr. Hans-Walter Latz.  See COPYING.\n'
        '   Reproduced by Tools/port-instructions.py; no Java runtime is used. */\n'
        '#import "DBProcessorPrivate.h"\n\n@implementation DBProcessor (Instructions)\n']
prototypes = []
for name, kind, code, body, chapter in ops:
    body = convert_calls(body)
    body = re.sub(r'Cpu\.(PC|savedPC|LF|GF16|GF32|MDS)', r'_state.\1', body)
    body = re.sub(r'\bshort\b', 'int16_t', body)
    body = re.sub(r'\blong\b', 'uint64_t', body)
    body = re.sub(r'\bint\b', 'int64_t', body)
    body = body.replace('(s >>> 16) >= t', '(s >>> 16) >= (uint64_t)t')
    body = body.replace('>>>', '>>')  # operands here are nonnegative or masked
    for old, new in [('signExtendByte', 'db_sign_byte'), ('signExtendWord', 'db_sign_word'),
                     ('shiftShort', 'db_shift_word'), ('shiftLong', 'db_shift_long'),
                     ('rotateShort', 'db_rotate_word')]:
        body = body.replace(old + '(', new + ' (')
    body = re.sub(r'(?<!@)"([^"\n]*)"', r'@"\1"', body)
    text.append('/* ' + chapter + ': ' + name + '. */\n- (void) ' + name + '\n{' + body + '\n}\n')
    prototypes.append('/** Execute the reference ' + name + ' instruction. */\n- (void) ' + name + ';')
text.append('@end\n')
(root / 'Source/DBInstructions.m').write_text('\n'.join(text))
(root / 'Source/DBInstructions.h').write_text('/** <title>Internal opcode methods</title>\n    <author name="Daybreak contributors"></author>\n    Copyright (c) 2017, Dr. Hans-Walter Latz. See COPYING. */\n#ifndef DAYBREAK_INSTRUCTIONS_H\n#define DAYBREAK_INSTRUCTIONS_H\n#import \"DBProcessor.h\"\n/** Internal methods corresponding to Dwarf opcode implementations. */\n@interface DBProcessor (Instructions)\n' + '\n'.join(prototypes) + '\n@end\n#endif\n')
dispatch = []
for escape in (False, True):
    dispatch.append('  if (escape)' if escape else '  if (!escape)')
    dispatch.append('    {\n      switch (opcode)\n        {')
    codes = sorted(set(code for _, kind, code, _, _ in ops if (kind == 'ESC') == escape))
    for code in codes:
        variants = [(name, kind) for name, kind, c, _, _ in ops if c == code and (kind == 'ESC') == escape]
        dispatch.append('        case 0x%02x:' % code)
        dispatch.append('          if (!execute) return YES;')
        if len(variants) == 2:
            for name, kind in variants:
                dispatch.append('          if (%s_post40) [self %s];' % ('!' if kind == 'OPCo' else '', name))
        else:
            name, kind = variants[0]
            if kind == 'OPCn':
                dispatch[-1] = '          if (!_post40) return NO;\n          if (!execute) return YES;'
            dispatch.append('          [self ' + name + '];')
        dispatch.append('          return YES;')
    dispatch.append('        default: break;\n        }\n    }')
(root / 'Source/DBInstructionDispatch.inc').write_text('\n'.join(dispatch) + '\n')
print('Ported', len(ops), 'instruction implementations')
