/* Derived from Dwarf by Dr. Hans-Walter Latz. See COPYING. */
#import "DBProcessorPrivate.h"
#import "DBBlocks.h"
struct DBBitBlt
{
  uint32_t source, destination;
  uint16_t srcBit, dstBit, width, height, flags, row;
  int32_t srcStride, dstStride;
  uint16_t pattern[256], colors[2];
  unsigned int sourceDepth, destinationDepth;
  unsigned int patternWidth, patternHeight, patternY, function;
  BOOL isPattern, unpacked, loaded;
};

struct DBTrapezoid
{
  uint32_t destination, source, left, right, leftDelta, rightDelta;
  uint16_t stride, sourcePixel, flags, height, row;
};

@implementation DBProcessor (Blocks)
- (BOOL) blockOpcode: (uint8_t)opcode escape: (BOOL)escape execute: (BOOL)execute
{
  if (escape && opcode == 0xa4)
    {
      if (execute)
        [self trapZBlt];
      return YES;
    }
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
  uint16_t line[32769];
  if (_state.SP == (opcode == 0xc2 ? 11U : 1U))
    {
      uint16_t pointer = 0;
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
      blt->sourceDepth = _displayDepth == 8 && (blt->flags & 0x4000) ? 8 : 1;
      blt->destinationDepth
          = _displayDepth == 8 && (blt->flags & 0x2000) ? 8 : 1;
      if (opcode == 0x2b && _displayDepth == 8)
        {
          blt->sourceDepth = blt->source >= _displayVirtualStart
                                     && blt->source < _displayVirtualEnd
                                 ? 8
                                 : 1;
          blt->destinationDepth
              = blt->destination >= _displayVirtualStart
                        && blt->destination < _displayVirtualEnd
                    ? 8
                    : 1;
        }
      blt->colors[0] = opcode == 0xc0 ? [self readMDSWord: pointer + 11] : 0;
      blt->colors[1] = opcode == 0xc0 ? [self readMDSWord: pointer + 12] : 1;
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
  dst = (int64_t) blt->destination * 16 + blt->dstBit * blt->destinationDepth
        + (int64_t) blt->row * blt->dstStride * blt->destinationDepth;
  src = (int64_t) blt->source * 16 + blt->srcBit * blt->sourceDepth
        + (int64_t) blt->row * blt->srcStride * blt->sourceDepth;
  if (dst < 0 || (!blt->isPattern && src < 0))
    [self pointerTrap];
  firstWord = (uint32_t) (dst / 16);
  offset = dst & 15;
  words = (offset + blt->width * blt->destinationDepth + 15) / 16;
  for (i = 0; i < words; i++)
    {
      [_memory validateWord: firstWord + i writing: YES];
      line[i] = [_memory readWord: firstWord + i];
    }
  for (i = 0; i < blt->width; i++)
    {
      unsigned int s, d, result, bit = offset + i * blt->destinationDepth;
      unsigned int pixelMask = (1U << blt->destinationDepth) - 1;
      unsigned int shift = 16 - blt->destinationDepth - (bit & 15);
      unsigned int mask = pixelMask << shift;
      if (blt->isPattern)
        {
          unsigned int y = (blt->patternY + blt->row) % blt->patternHeight;
          unsigned int x = (blt->srcBit + i)
                           % (blt->patternWidth * (blt->unpacked ? 1 : 16));
          uint16_t word = blt->pattern[y * blt->patternWidth
                                       + (blt->unpacked ? x : x / 16)];
          s = blt->unpacked ? (blt->sourceDepth == 8 ? word & 255 : word != 0)
                            : (word >> (15 - (x & 15))) & 1;
        }
      else
        {
          int64_t sourceBit = src + i * blt->sourceDepth;
          s = ([_memory readWord: (uint32_t) (sourceBit / 16)]
               >> (16 - blt->sourceDepth - (sourceBit & 15)))
              & ((1U << blt->sourceDepth) - 1);
        }
      if (blt->flags & 0x0800)
        s ^= (1U << blt->sourceDepth) - 1;
      else if (_displayDepth == 8 && blt->sourceDepth == 1)
        s = blt->colors[s & 1];
      d = (line[bit / 16] & mask) >> shift;
      if (_displayDepth == 8 && blt->destinationDepth == 1)
        d = blt->colors[d];
      switch (blt->function)
        {
        case 0:
          result = s;
          break;
        case 1:
          result = d > 1 ? d : s;
          break;
        case 2:
          result = s == 0 ? 0 : d;
          break;
        case 3:
          result = d == 0 ? 0 : s;
          break;
        case 4:
          result = s == 0 ? d : s;
          break;
        case 5:
          result = d == 0 ? s : d;
          break;
        case 6:
          result = (!s != !d);
          break;
        default:
          result = s ^ d;
        }
      line[bit / 16]
          = (line[bit / 16] & ~mask) | ((result & pixelMask) << shift);
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
- (void) trapZBlt
{
  NSMutableData *storage;
  struct DBTrapezoid *t;
  NSNumber *key;
  uint32_t identifier;
  int32_t left, right, width;
  uint16_t line[4097];
  unsigned int i, words, offset, patternWidth, patternHeight, patternY;
  int64_t destination;
  if (_state.SP == 2)
    {
      uint32_t pointer = [self popLong];
      storage = [NSMutableData dataWithLength: sizeof (struct DBTrapezoid)];
      t = [storage mutableBytes];
      t->destination = [_memory readDoubleWord: pointer];
      t->stride = [_memory readWord: pointer + 3];
      t->source = [_memory readDoubleWord: pointer + 4];
      t->sourcePixel = [_memory readWord: pointer + 6];
      t->flags = [_memory readWord: pointer + 7];
      t->left = [_memory readDoubleWord: pointer + 8];
      t->leftDelta = [_memory readDoubleWord: pointer + 10];
      t->right = [_memory readDoubleWord: pointer + 12];
      t->rightDelta = [_memory readDoubleWord: pointer + 14];
      t->height = [_memory readWord: pointer + 16];
      if (t->height == 0)
        return;
      if (_bitBlts == nil)
        _bitBlts = [[NSMutableDictionary alloc] init];
      do
        {
          identifier = ++_nextBitBlt;
          key = [NSNumber numberWithUnsignedInt: identifier];
        }
      while (!identifier || [_bitBlts objectForKey: key]);
      [_bitBlts setObject: storage forKey: key];
      [self pushLong: identifier];
      [self push: 0xa4];
      _state.savedSP = 3;
    }
  else if (_state.SP == 3)
    {
      if ((uint16_t) [self pop] != 0xa4)
        [self hardwareError: @"Invalid trapezoid continuation"];
      identifier = [self popLong];
      _state.SP = 3;
      key = [NSNumber numberWithUnsignedInt: identifier];
      storage = [_bitBlts objectForKey: key];
      if ([storage length] != sizeof (struct DBTrapezoid))
        [self hardwareError: @"Missing trapezoid continuation"];
      t = [storage mutableBytes];
    }
  else
    {
      [self hardwareError: @"Invalid TRAPZBLT operands"];
      return;
    }
  left = (int32_t) (t->left + t->leftDelta * t->row) >> 16;
  right = (int32_t) (t->right + t->rightDelta * t->row) >> 16;
  width = MAX (right - left, 1);
  destination = (int64_t) t->destination * 16 + t->row * t->stride + left;
  if (destination < 0 || width > 65535)
    [self pointerTrap];
  offset = destination & 15;
  words = (offset + width + 15) / 16;
  for (i = 0; i < words; i++)
    {
      [_memory validateWord: destination / 16 + i writing: YES];
      line[i] = [_memory readWord: destination / 16 + i];
    }
  patternWidth = ((t->flags >> 4) & 15) + 1;
  patternHeight = (t->flags & 15) + 1;
  patternY = (t->flags >> 8) & 15;
  for (i = 0; i < (unsigned int) width; i++)
    {
      unsigned int x = (t->sourcePixel + left - ((int32_t) t->left >> 16) + i)
                       % (patternWidth * 16);
      uint32_t source = t->source - patternY
                        + ((patternY + t->row) % patternHeight) * patternWidth
                        + x / 16;
      unsigned int bit = offset + i, mask = 0x8000 >> (bit & 15);
      unsigned int value = ([_memory readWord: source] >> (15 - (x & 15))) & 1;
      unsigned int old = (line[bit / 16] & mask) != 0;
      if (t->flags & 0x8000)
        value ^= 1;
      switch ((t->flags >> 13) & 3)
        {
        case 1:
          value &= old;
          break;
        case 2:
          value |= old;
          break;
        case 3:
          value ^= old;
          break;
        default:
          break;
        }
      line[bit / 16] = value ? line[bit / 16] | mask : line[bit / 16] & ~mask;
    }
  for (i = 0; i < words; i++)
    [_memory writeWord: destination / 16 + i value: line[i]];
  if (++t->row == t->height)
    {
      _state.SP = _state.savedSP = 0;
      [_bitBlts removeObjectForKey: key];
    }
  else
    _state.PC = _state.savedPC;
}
@end
