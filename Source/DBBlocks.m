/* Derived from Dwarf by Dr. Hans-Walter Latz. See COPYING. */
#import "DBProcessorPrivate.h"
#import "DBBlocks.h"
struct DBBitBlt
{
  uint32_t source, destination;
  uint16_t srcBit, dstBit, width, height, flags, row;
  int32_t srcStride, dstStride;
  uint16_t pattern[256];
  unsigned int patternWidth, patternHeight, patternY, function;
  BOOL isPattern, unpacked, loaded;
};

@implementation DBProcessor (Blocks)
- (BOOL) blockOpcode: (uint8_t)opcode escape: (BOOL)escape execute: (BOOL)execute
{
  if (escape && (opcode == 0x2b || opcode == 0xc0 || opcode == 0xc2))
    {
      if (execute)
        [self bitBlt: opcode];
      return YES;
    }
  BOOL supported = escape ? ((opcode >= 0x27 && opcode <= 0x2a)
                             || opcode == 0x2d || opcode == 0x2e)
                          : (opcode >= 0xf3 && opcode <= 0xf6);
  uint32_t source, destination, count, a, b;
  BOOL longSource, longDestination, codeSource, reversed, compare;
  if (!supported || !execute)
    return supported;
  if (escape && (opcode == 0x2d || opcode == 0x2e))
    {
      a = (uint16_t) [self pop];
      source = [self popLong];
      count = (uint16_t) [self pop];
      b = (uint16_t) [self pop];
      destination = [self popLong];
      if (count == 0)
        return YES;
      source += a / 2;
      a &= 1;
      destination += b / 2;
      b &= 1;
      reversed = opcode == 0x2e;
      [_memory storeByte: destination
                  offset: b + (reversed ? count - 1 : 0)
                   value: [_memory fetchByte: source
                                     offset: a + (reversed ? count - 1 : 0)]];
      count--;
      if (count)
        {
          [self pushLong: destination];
          [self push: b + !reversed];
          [self push: count];
          [self pushLong: source];
          [self push: a + !reversed];
          _state.PC = _state.savedPC;
        }
      return YES;
    }
  if (escape && opcode == 0x2a)
    {
      source = [self popLong];
      count = (uint16_t) [self pop];
      a = (uint16_t) [self pop];
      if (count)
        {
          b = (a + [_memory readWord: source]) & 65535;
          if (a > b)
            b++;
          a = ((b << 1) | (b >> 15)) & 65535;
          count--;
          source++;
        }
      if (count)
        {
          [self push: a];
          [self push: count];
          [self pushLong: source];
          _state.PC = _state.savedPC;
        }
      else
        [self push: a == 65535 ? 0 : a];
      return YES;
    }
  longDestination = escape || opcode == 0xf4 || opcode == 0xf6;
  longSource = escape ? opcode != 0x29 : opcode == 0xf4;
  codeSource = escape ? opcode == 0x29 : opcode >= 0xf5;
  reversed = escape && opcode == 0x27;
  compare = escape && (opcode == 0x28 || opcode == 0x29);
  destination
      = longDestination ? (uint32_t) [self popLong] : (uint16_t) [self pop];
  count = (uint16_t) [self pop];
  source = longSource ? (uint32_t) [self popLong] : (uint16_t) [self pop];
  if (count != 0)
    {
      uint32_t offset = reversed ? count - 1 : 0;
      a = codeSource   ? [self readCode: source + offset]
          : longSource ? [_memory readWord: source + offset]
                       : [self readMDSWord: source + offset];
      if (compare)
        {
          if (a != [_memory readWord: destination])
            {
              [self push: 0];
              return YES;
            }
        }
      else if (longDestination)
        [_memory writeWord: destination + offset value: a];
      else
        [self writeMDSWord: destination + offset value: a];
      count--;
      if (!reversed)
        {
          source++;
          destination++;
        }
    }
  if (count != 0)
    {
      if (longSource)
        [self pushLong: source];
      else
        [self push: source];
      [self push: count];
      if (longDestination)
        [self pushLong: destination];
      else
        [self push: destination];
      _state.PC = _state.savedPC;
    }
  else if (compare)
    [self push: 1];
  return YES;
}
- (void) bitBlt: (uint8_t)opcode
{
  NSMutableData *storage;
  struct DBBitBlt *blt;
  NSNumber *key;
  uint32_t identifier;
  unsigned int i, words, offset;
  int64_t dst, src;
  uint32_t firstWord;
  uint16_t line[4097];
  if (_state.SP == (opcode == 0xc2 ? 11U : 1U))
    {
      uint16_t pointer;
      storage = [NSMutableData dataWithLength: sizeof (struct DBBitBlt)];
      blt = [storage mutableBytes];
      if (opcode == 0xc2)
        {
          blt->flags = [self pop];
          blt->height = [self pop];
          blt->width = [self pop];
          blt->srcStride = [self pop];
          blt->srcBit = [self pop];
          blt->source = [self popLong];
          blt->dstStride = [self pop];
          blt->dstBit = [self pop];
          blt->destination = [self popLong];
        }
      else
        {
          pointer = [self pop];
          blt->destination = [self readMDSDoubleWord: pointer];
          blt->dstBit = [self readMDSWord: pointer + 2];
          blt->dstStride = (int16_t) [self readMDSWord: pointer + 3];
          blt->source = [self readMDSDoubleWord: pointer + 4];
          blt->srcBit = [self readMDSWord: pointer + 6];
          blt->srcStride = (int16_t) [self readMDSWord: pointer + 7];
          blt->width = [self readMDSWord: pointer + 8];
          blt->height = [self readMDSWord: pointer + 9];
          blt->flags = [self readMDSWord: pointer + 10];
        }
      if (blt->width == 0 || blt->height == 0)
        return;
      blt->isPattern = (blt->flags & 0x1000) != 0;
      blt->unpacked = opcode != 0x2b && (blt->srcStride & 0xf000) != 0;
      blt->patternWidth = ((blt->srcStride >> 4) & 15) + 1;
      blt->patternHeight = (blt->srcStride & 15) + 1;
      blt->patternY = (blt->srcStride >> 8) & 15;
      blt->function = (blt->flags >> 8) & 7;
      if (opcode == 0x2b)
        {
          static const unsigned int map[4] = { 0, 3, 5, 7 };
          blt->function = map[(blt->flags >> 9) & 3];
        }
      if ((blt->flags & 0x8000)
          && !(opcode == 0x2b && blt->srcStride > 0 && blt->dstStride > 0))
        {
          blt->dstStride = -abs (blt->dstStride);
          if (!blt->isPattern)
            blt->srcStride = -abs (blt->srcStride);
        }
      else
        {
          blt->dstStride = abs (blt->dstStride);
          if (!blt->isPattern)
            blt->srcStride = abs (blt->srcStride);
        }
      if (_bitBlts == nil)
        _bitBlts = [[NSMutableDictionary alloc] init];
      do
        {
          identifier = ++_nextBitBlt;
          key = [NSNumber numberWithUnsignedInt: identifier];
        }
      while (identifier == 0 || [_bitBlts objectForKey: key] != nil);
      [_bitBlts setObject: storage forKey: key];
      [self pushLong: identifier];
      _state.savedSP = 2;
    }
  else if (_state.SP == 2)
    {
      identifier = (uint32_t) [self popLong];
      _state.SP = 2;
      key = [NSNumber numberWithUnsignedInt: identifier];
      storage = [_bitBlts objectForKey: key];
      if (storage == nil)
        [self hardwareError: @"Unknown BITBLT continuation"];
      blt = [storage mutableBytes];
    }
  else
    {
      [NSException raise: @"DBStackError" format: @"Invalid BITBLT operands"];
      return;
    }
  if (blt->isPattern && !blt->loaded)
    {
      for (i = 0; i < blt->patternWidth * blt->patternHeight; i++)
        blt->pattern[i] = [_memory
            readWord: blt->source - blt->patternY * blt->patternWidth + i];
      blt->loaded = YES;
    }
  dst = (int64_t) blt->destination * 16 + blt->dstBit
        + (int64_t) blt->row * blt->dstStride;
  src = (int64_t) blt->source * 16 + blt->srcBit
        + (int64_t) blt->row * blt->srcStride;
  if (dst < 0 || (!blt->isPattern && src < 0))
    [self pointerTrap];
  firstWord = (uint32_t) (dst / 16);
  offset = dst & 15;
  words = (offset + blt->width + 15) / 16;
  for (i = 0; i < words; i++)
    {
      [_memory validateWord: firstWord + i writing: YES];
      line[i] = [_memory readWord: firstWord + i];
    }
  for (i = 0; i < blt->width; i++)
    {
      unsigned int s, d, result, bit = offset + i, mask = 0x8000 >> (bit & 15);
      if (blt->isPattern)
        {
          unsigned int y = (blt->patternY + blt->row) % blt->patternHeight;
          unsigned int x = (blt->srcBit + i)
                           % (blt->patternWidth * (blt->unpacked ? 1 : 16));
          uint16_t word = blt->pattern[y * blt->patternWidth
                                       + (blt->unpacked ? x : x / 16)];
          s = blt->unpacked ? word != 0 : (word >> (15 - (x & 15))) & 1;
        }
      else
        s = ([_memory readWord: (uint32_t) ((src + i) / 16)]
             >> (15 - ((src + i) & 15)))
            & 1;
      if (blt->flags & 0x0800)
        s ^= 1;
      d = (line[bit / 16] & mask) != 0;
      switch (blt->function)
        {
        case 0:
        case 1:
          result = s;
          break;
        case 2:
        case 3:
          result = s & d;
          break;
        case 4:
        case 5:
          result = s | d;
          break;
        default:
          result = s ^ d;
        }
      line[bit / 16] = result ? line[bit / 16] | mask : line[bit / 16] & ~mask;
    }
  for (i = 0; i < words; i++)
    [_memory writeWord: firstWord + i value: line[i]];
  if (++blt->row == blt->height)
    {
      _state.SP = _state.savedSP = 0;
      [_bitBlts removeObjectForKey: key];
    }
  else
    _state.PC = _state.savedPC;
}
@end
