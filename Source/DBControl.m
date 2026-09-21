/* Derived from Dwarf by Dr. Hans-Walter Latz. See COPYING. */
#import "DBProcessorPrivate.h"
#include <time.h>

static uint32_t
db_microseconds (void)
{
  struct timespec ts;
  clock_gettime (CLOCK_MONOTONIC, &ts);
  return (uint32_t) ((uint64_t) ts.tv_sec * 62500 + ts.tv_nsec / 16000);
}

@implementation DBProcessor (Control)
- (uint32_t) intervalTimer
{
  return db_microseconds () - _timerBase + _timerOffset;
}
- (void) setIntervalTimer: (uint32_t)value
{
  _timerBase = db_microseconds ();
  _timerOffset = value;
}
- (void) setGuestTraps: (BOOL)enabled
{
  _guestTraps = enabled;
}
- (void) checkEmptyStack
{
  if (_state.SP != 0)
    [NSException raise: @"DBStackError" format: @"Expected empty stack"];
}
- (uint16_t) allocateFrame: (uint16_t)index
{
  unsigned int count;
  for (count = 0; count < 256; count++)
    {
      uint16_t item;
      if (index > 255)
        [self hardwareError: @"Invalid allocation vector index"];
      item = [self readMDSWord: 0x100 + index];
      if ((item & 3) == 2)
        {
          index = item >> 2;
          continue;
        }
      if ((item & 3) != 0)
        {
          if (_guestTraps)
            [self fault: 0 parameter: index words: 1];
          [NSException raise: @"DBFrameFault"
                      format: @"No frame for size %u", index];
        }
      [self writeMDSWord: 0x100 + index value: [self readMDSWord: item]];
      return item;
    }
  [self hardwareError: @"Cyclic allocation vector"];
  return 0;
}
- (void) freeFrame: (uint16_t)frame
{
  uint16_t index = [self readMDSWord: frame - 4] & 255;
  [self writeMDSWord: frame value: [self readMDSWord: 0x100 + index]];
  [self writeMDSWord: 0x100 + index value: frame];
}
- (uint32_t) fetchLink: (uint8_t)offset
{
  uint16_t word = _post40 ? [_memory readWord: _state.GF32 - 1]
                          : [self readMDSWord: _state.GF16 - 3];
  if (word & 1)
    return [_memory readDoubleWord: _state.CB - (offset + 1) * 2];
  if (_post40)
    return [_memory readDoubleWord: _state.GF32 - 2 - (offset + 1) * 2];
  return [self readMDSDoubleWord: _state.GF16 - 4 - (offset + 1) * 2];
}
- (void) transfer: (uint32_t)destination
          source: (uint16_t)source
            type: (unsigned int)type
            free: (BOOL)releaseFrame
{
  uint32_t link = destination;
  uint16_t frame, pc, global;
  unsigned int depth = 0;
  BOOL indirect = NO;
  while ((link & 3) == 2)
    {
      if (type == 5 || ++depth > 65536)
        [self hardwareError: @"Invalid indirect transfer chain"];
      indirect = YES;
      link = [self readMDSDoubleWord: (uint16_t) link];
    }
  if ((link & 3) == 0)
    {
      frame = (uint16_t) link;
      if (frame == 0)
        {
          [self trap: 6 parameter: source words: 1];
          return;
        }
      global = [self readMDSWord: frame - 2];
      pc = [self readMDSWord: frame - 1];
    }
  else
    {
      frame = 0;
      global = (uint16_t) link & (_post40 ? 0xfffc : 0xfffe);
      if (_post40 && (link & 3) == 1 && global != 0)
        global = [self readMDSWord: global - 1] & 0xfffc;
      pc = link >> 16;
    }
  if (global == 0 || pc == 0)
    {
      [self trap: 9 parameter: destination words: 2];
      return;
    }
  if (_post40)
    {
      _state.GFI = global;
      _state.GF32 = [_memory readDoubleWord: 0x20000 + global];
      _state.CB = [_memory readDoubleWord: 0x20002 + global];
    }
  else
    {
      _state.GF16 = global;
      _state.GF32 = _state.MDS + global;
      _state.CB = [self readMDSDoubleWord: global - 2];
    }
  if (_state.CB & 1)
    {
      [self trap: 7 parameter: global words: 1];
      return;
    }
  if ((link & 3) != 0)
    {
      frame = [self allocateFrame: [_memory fetchByte: _state.CB offset: pc]];
      pc++;
      [self writeMDSWord: frame - 2 value: global];
      [self writeMDSWord: frame - 3 value: source];
    }
  else if (type == 5)
    {
      [self writeMDSWord: frame - 3 value: source];
      _state.WDC++;
    }
  if (indirect)
    {
      [self push: destination];
      [self push: source];
      [self discard];
      [self discard];
    }
  if (releaseFrame)
    [self freeFrame: _state.LF];
  _state.LF = frame;
  _state.PC = pc;
  [self checkTransferTrap: destination type: type];
}
- (void) call: (uint32_t)destination
{
  [self writeMDSWord: _state.LF - 1 value: _state.PC];
  [self transfer: destination source: _state.LF type: 1 free: NO];
}
- (void) checkTransferTrap: (uint32_t)destination type: (unsigned int)type
{
  if ((_state.XTS & 1) != 0)
    {
      uint16_t word = _post40 ? [_memory readWord: _state.GF32 - 1]
                              : [self readMDSWord: _state.GF16 - 3];
      if (word & 2)
        {
          _state.XTS >>= 1;
          _state.PC = _state.savedPC;
          _state.SP = _state.savedSP;
          if (_state.PC > 8)
            [self writeMDSWord: _state.LF - 1 value: _state.PC];
          [self transfer: [self readMDSDoubleWord: 0x208]
                  source: _state.LF
                    type: 5
                    free: NO];
          [self writeMDSWord: _state.LF value: destination];
          [self writeMDSWord: _state.LF + 1 value: destination >> 16];
          [self writeMDSWord: _state.LF + 2 value: type];
          [NSException raise: @"DBMesaAbort" format: @"Transfer trap"];
        }
    }
  else
    _state.XTS >>= 1;
}
- (void) saveStack: (uint32_t)address
{
  unsigned int i;
  for (i = 0; i < DB_STACK_LENGTH; i++)
    [_memory writeWord: address + i value: _state.stack[i]];
  [_memory writeWord: address + 14 value: (_state.breakByte << 8) | _state.SP];
  _state.SP = _state.savedSP = _state.breakByte = 0;
}
- (void) loadStack: (uint32_t)address
{
  unsigned int i;
  uint16_t word = [_memory readWord: address + 14];
  if ((word & 15) > DB_STACK_LENGTH)
    [self hardwareError: @"Invalid saved stack depth"];
  for (i = 0; i < DB_STACK_LENGTH; i++)
    _state.stack[i] = [_memory readWord: address + i];
  _state.SP = _state.savedSP = word & 15;
  _state.breakByte = word >> 8;
}
- (void) trap: (unsigned int)index
    parameter: (uint32_t)value
        words: (unsigned int)words
{
  uint32_t link;
  if (!_guestTraps)
    [NSException raise: @"DBControlTrap"
                format: @"Mesa trap %u parameter %08x", index, value];
  link = [self readMDSDoubleWord: 0x200 + (index & 255) * 2];
  _state.PC = _state.savedPC;
  _state.SP = _state.savedSP;
  if (_state.PC > 8)
    [self writeMDSWord: _state.LF - 1 value: _state.PC];
  [self transfer: link source: _state.LF type: 5 free: NO];
  if (words > 0)
    [self writeMDSWord: _state.LF value: value];
  if (words > 1)
    [self writeMDSWord: _state.LF + 1 value: value >> 16];
  [NSException raise: @"DBMesaAbort" format: @"Mesa trap"];
}
- (void) dispatchException: (NSException *)exception opcode: (uint8_t)opcode
{
  if (++_trapDepth > 16)
    {
      _trapDepth = 0;
      [self hardwareError: @"Recursive fault during trap delivery"];
    }
  NS_DURING
  if (![self deliverException: exception opcode: opcode])
    [exception raise];
  NS_HANDLER
  if (![[localException name] isEqual: @"DBMesaAbort"])
    {
      if ([[localException name] isEqual: @"DBPageFault"] ||
          [[localException name] isEqual: @"DBWriteProtectFault"])
        [self dispatchException: localException opcode: opcode];
      else
        {
          _trapDepth = 0;
          [localException raise];
        }
    }
  NS_ENDHANDLER
  if (_trapDepth != 0)
    _trapDepth--;
}
- (BOOL) deliverException: (NSException *)exception opcode: (uint8_t)opcode
{
  NSString *name = [exception name];
  if ([name isEqual: @"DBMesaAbort"])
    return YES;
  if (!_guestTraps)
    return NO;
  if ([name isEqual: @"DBPageFault"] || [name isEqual: @"DBWriteProtectFault"])
    [self fault: [name isEqual: @"DBPageFault"] ? 1 : 2
        parameter: [[[exception userInfo] objectForKey: @"address"]
                      unsignedIntValue]
            words: 2];
  if ([name isEqual: @"DBEscapeOpcodeTrap"])
    {
      uint32_t link = [self readMDSDoubleWord: 0x400 + opcode * 2];
      _state.PC = _state.savedPC;
      _state.SP = _state.savedSP;
      if (_state.PC > 8)
        [self writeMDSWord: _state.LF - 1 value: _state.PC];
      [self transfer: link source: _state.LF type: 5 free: NO];
      [self writeMDSWord: _state.LF value: opcode];
      return YES;
    }
  if ([name isEqual: @"DBOpcodeTrap"])
    [self trap: 5 parameter: opcode words: 1];
  if ([name isEqual: @"DBStackError"])
    [self trap: 2 parameter: 0 words: 0];
  if ([name isEqual: @"DBBoundsTrap"])
    [self trap: 14 parameter: 0 words: 0];
  if ([name isEqual: @"DBPointerTrap"])
    [self trap: 15 parameter: 0 words: 0];
  if ([name isEqual: @"DBDivideZeroTrap"])
    [self trap: 10 parameter: 0 words: 0];
  if ([name isEqual: @"DBDivideCheckTrap"])
    [self trap: 11 parameter: 0 words: 0];
  return NO;
}
- (BOOL) controlOpcode: (uint8_t)opcode escape: (BOOL)escape execute: (BOOL)execute
{
  BOOL supported = escape
                       ? ((opcode >= 0x0a && opcode <= 0x0e)
                          || (opcode >= 0x20 && opcode <= 0x23)
                          || (opcode >= 0x70 && opcode <= 0x7e))
                       : (opcode == 0x3d || (opcode >= 0x77 && opcode <= 0x7a)
                          || (opcode >= 0xdf && opcode <= 0xf0)
                          || (opcode == 0xfd && _post40));
  uint16_t a, b, pc;
  uint32_t link;
  if (!supported || !execute)
    return supported;
  if (!escape)
    {
      if (opcode >= 0xdf && opcode <= 0xeb)
        {
          [self call: [self fetchLink: opcode - 0xdf]];
          return YES;
        }
      switch (opcode)
        {
        case 0x3d:
          if (_state.breakByte == 0)
            [self trap: 0 parameter: 0 words: 0];
          else if (![self dispatch: _state.breakByte escape: NO execute: YES])
            [self trap: 5 parameter: _state.breakByte words: 1];
          _state.breakByte = 0;
          break;
        case 0x77:
          [self pushLong: [self fetchLink: [self nextCodeByte]]];
          break;
        case 0x78:
          [self push: [_memory readWord: [self fetchLink: [self nextCodeByte]]]];
          break;
        case 0x79:
          [self
              pushLong: [_memory
                           readDoubleWord: [self
                                              fetchLink: [self nextCodeByte]]]];
          break;
        case 0x7a:
          a = [self nextCodeByte];
          [self recover];
          b = [self pop];
          [self writeMDSWord: _state.LF value: b - a];
          break;
        case 0xec:
          [self call: [self fetchLink: [self nextCodeByte]]];
          break;
        case 0xed:
          pc = [self nextCodeWord];
          [self writeMDSWord: _state.LF - 1 value: _state.PC];
          if (pc == 0)
            [self trap: 9 parameter: 0 words: 2];
          a = [self allocateFrame: [_memory fetchByte: _state.CB offset: pc]];
          [self writeMDSWord: a - 2 value: _post40 ? _state.GFI : _state.GF16];
          [self writeMDSWord: a - 3 value: _state.LF];
          _state.LF = a;
          _state.PC = pc + 1;
          [self checkTransferTrap: ((uint32_t) (_post40 ? _state.GFI
                                                       : (_state.GF16 | 1))
                                   << 16)
                                  | pc
                             type: 2];
          break;
        case 0xee:
          [self call: (uint32_t) [self popLong]];
          break;
        case 0xef:
          [self transfer: [self readMDSWord: _state.LF - 3]
                  source: 0
                    type: 0
                    free: YES];
          break;
        case 0xf0:
          [self call: [self readMDSDoubleWord: 0x200 + [self nextCodeByte] * 2]];
          break;
        case 0xfd:
          a = [self nextCodeWord];
          [self push: _state.GFI | 3];
          [self push: a];
          break;
        }
      return YES;
    }
  switch (opcode)
    {
    case 0x0a:
      [self push: [self allocateFrame: (uint16_t) [self pop]]];
      break;
    case 0x0b:
      [self freeFrame: [self pop]];
      break;
    case 0x0c:
      [self recover];
      [self recover];
      a = [self pop];
      b = [self pop];
      [self writeMDSWord: b value: 0];
      if (a != 0)
        [self writeMDSWord: b + 2 value: a];
      break;
    case 0x0d:
    case 0x0e:
      [self pop];
      a = [self pop];
      [self writeMDSWord: _state.LF - 1 value: _state.PC];
      [self writeMDSWord: a value: _state.LF];
      [self transfer: [self readMDSDoubleWord: a + 2] source: a type: 3 free: NO];
      break;
    case 0x20:
      [self saveStack: [self lengthenPointer: _state.LF + [self nextCodeByte]]];
      break;
    case 0x23:
      [self loadStack: [self lengthenPointer: _state.LF + [self nextCodeByte]]];
      break;
    case 0x21:
    case 0x22:
      a = _state.LF + [self nextCodeByte];
      link = [self readMDSDoubleWord: a + 2];
      b = [self readMDSWord: a];
      if (opcode == 0x21)
        [self writeMDSWord: _state.LF - 1 value: _state.PC];
      [self transfer: link source: b type: 4 free: opcode == 0x22];
      if (opcode == 0x21 && _state.WDC != 0)
        _state.WDC--;
      break;
    case 0x70:
      _state.PSB = (uint16_t) [self pop] / 8;
      break;
    case 0x71:
      _state.MDS = (uint32_t) (uint16_t) [self pop] << 16;
      break;
    case 0x72:
      _state.WP = [self pop];
      break;
    case 0x73:
      _state.WDC = [self pop];
      break;
    case 0x74:
      _state.PTC = [self pop];
      _lastPulse = [self intervalTimer];
      break;
    case 0x75:
      [self setIntervalTimer: (uint32_t) [self popLong]];
      break;
    case 0x76:
      _state.XTS = [self pop];
      break;
    case 0x77:
      _state.MP = [self pop];
      break;
    case 0x78:
      [self push: _state.PSB * 8];
      break;
    case 0x79:
      [self push: _state.MDS >> 16];
      break;
    case 0x7a:
      [self push: _state.WP];
      break;
    case 0x7b:
      [self push: _state.WDC];
      break;
    case 0x7c:
      [self push: _state.PTC];
      break;
    case 0x7d:
      [self pushLong: [self intervalTimer]];
      break;
    case 0x7e:
      [self push: _state.XTS];
      break;
    }
  return YES;
}
@end
