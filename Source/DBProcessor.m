/* Copyright (c) 2017, Dr. Hans-Walter Latz.  See COPYING. */
#import "DBProcessorPrivate.h"
#include <string.h>
#include <stdio.h>
#include <stdlib.h>

@implementation DBProcessor
- (id) initWithMemory: (DBMemory *)memory post40: (BOOL)post40
{
  self = [super init];
  if (self != nil)
    {
      if (memory == nil)
        {
          [self release];
          [NSException raise: NSInvalidArgumentException
                      format: @"Memory is required"];
          return nil;
        }
      _memory = [memory retain];
      _post40 = post40;
      [self reset];
    }
  return self;
}
- (void) dealloc
{
  [_bitBlts release];
  [_memory release];
  [super dealloc];
}
- (DBMemory *) memory
{
  return _memory;
}
- (DBProcessorState *) state
{
  return &_state;
}
- (void) reset
{
  memset (&_state, 0, sizeof (_state));
  _state.WDC = _state.PTC = 1;
  _state.running = YES;
  _guestTraps = NO;
  [_bitBlts removeAllObjects];
  _nextBitBlt = 0;
  [self setIntervalTimer: 0];
  _lastPulse = 0;
}
- (void) push: (uint16_t)value
{
  if (_state.SP >= DB_STACK_LENGTH)
    [NSException raise: @"DBStackError" format: @"Evaluation stack overflow"];
  _state.stack[_state.SP++] = value;
}
- (int16_t) pop
{
  if (_state.SP == 0)
    [NSException raise: @"DBStackError" format: @"Evaluation stack underflow"];
  return (int16_t) _state.stack[--_state.SP];
}
- (void) pushLong: (uint32_t)value
{
  if (_state.SP > DB_STACK_LENGTH - 2)
    [NSException raise: @"DBStackError" format: @"Double-word stack overflow"];
  [self push: value & 65535];
  [self push: value >> 16];
}
- (int32_t) popLong
{
  uint32_t high, low;
  if (_state.SP < 2)
    [NSException raise: @"DBStackError" format: @"Double-word stack underflow"];
  high = (uint16_t) [self pop];
  low = (uint16_t) [self pop];
  return (int32_t) ((high << 16) | low);
}
- (void) recover
{
  if (_state.SP >= DB_STACK_LENGTH)
    [NSException raise: @"DBStackError" format: @"Recover overflow"];
  _state.SP++;
}
- (void) discard
{
  (void) [self pop];
}
- (void) step
{
  DBProcessorState saved = _state;
  volatile uint8_t opcode = 0;
  _state.savedPC = _state.PC;
  _state.savedSP = _state.SP;
  NS_DURING
  opcode = [self nextCodeByte];
  BOOL escape = opcode == 0xf8 || opcode == 0xf9;
  if (escape)
    opcode = [self nextCodeByte];
  if (![self dispatch: opcode escape: escape execute: YES])
    {
      if (getenv ("DAYBREAK_TRACE") != NULL
          && !(escape
               && (opcode == 0x2c || (opcode >= 0x45 && opcode <= 0x4f))))
        fprintf (stderr, "unimplemented %s %02x CB=%x PC=%x\n",
                 escape ? "ESC" : "OP", opcode, _state.CB, _state.savedPC);
      [NSException raise: escape ? @"DBEscapeOpcodeTrap" : @"DBOpcodeTrap"
                  format: @"Unsupported %@ opcode 0x%02x at CB=%08x PC=%04x",
                         escape ? @"escape" : @"primary", opcode, _state.CB,
                         _state.savedPC];
    }
  _state.instructions++;
  NS_HANDLER
  if (![[localException name] isEqual: @"DBMesaAbort"])
    {
      if (!_guestTraps)
        {
          _state = saved;
          [localException raise];
        }
      [self dispatchException: localException opcode: opcode];
    }
  NS_ENDHANDLER
}
- (void) runForInstructions: (uint32_t)count
{
  uint32_t i;
  for (i = 0; i < count; i++)
    {
      if (_guestTraps)
        [self pollProcesses];
      if (!_state.running)
        break;
      [self step];
    }
}
- (BOOL) supportsOpcode: (uint8_t)opcode escape: (BOOL)escape
{
  return [self dispatch: opcode escape: escape execute: NO];
}
@end

@implementation DBProcessor (Private)
- (int16_t) popRecover
{
  if (_state.SP == 0)
    [NSException raise: @"DBStackError" format: @"Peek underflow"];
  return (int16_t) _state.stack[_state.SP - 1];
}
- (uint32_t) lengthenPointer: (uint32_t)pointer
{
  return _state.MDS + (pointer & 65535);
}
- (uint8_t) nextCodeByte
{
  uint8_t value = [_memory fetchByte: _state.CB offset: _state.PC];
  _state.PC++;
  return value;
}
- (uint16_t) nextCodeWord
{
  uint16_t high = [self nextCodeByte];
  return (high << 8) | [self nextCodeByte];
}
- (uint16_t) readCode: (uint32_t)offset
{
  return [_memory readWord: _state.CB + (offset & 65535)];
}
- (uint16_t) readMDSWord: (uint32_t)pointer
{
  return [_memory readWord: [self lengthenPointer: pointer]];
}
- (uint16_t) readMDSWord: (uint32_t)pointer offset: (uint32_t)offset
{
  return [self readMDSWord: pointer + offset];
}
- (uint32_t) readMDSDoubleWord: (uint32_t)pointer
{
  return [_memory readDoubleWord: [self lengthenPointer: pointer]];
}
- (uint32_t) readMDSDoubleWord: (uint32_t)pointer offset: (uint32_t)offset
{
  return [self readMDSDoubleWord: pointer + offset];
}
- (void) writeMDSWord: (uint32_t)pointer value: (uint16_t)value
{
  [_memory writeWord: [self lengthenPointer: pointer] value: value];
}
- (void) writeMDSWord: (uint32_t)pointer
              offset: (uint32_t)offset
               value: (uint16_t)value
{
  [self writeMDSWord: pointer + offset value: value];
}
- (float) popFloat
{
  uint32_t bits = (uint32_t) [self popLong];
  float value;
  memcpy (&value, &bits, sizeof (value));
  return value;
}
- (void) pushFloat: (float)value
{
  uint32_t bits;
  memcpy (&bits, &value, sizeof (bits));
  [self pushLong: bits];
}
- (void) boundsTrap
{
  [NSException raise: @"DBBoundsTrap" format: @"Index outside bounds"];
}
- (void) pointerTrap
{
  [NSException raise: @"DBPointerTrap" format: @"Nil Mesa pointer"];
}
- (void) divZeroTrap
{
  [NSException raise: @"DBDivideZeroTrap" format: @"Division by zero"];
}
- (void) divCheckTrap
{
  [NSException raise: @"DBDivideCheckTrap" format: @"Quotient overflow"];
}
- (void) hardwareError: (NSString *)reason
{
  [NSException raise: @"DBHardwareError" format: @"%@", reason];
}
- (BOOL) dispatch: (uint8_t)opcode escape: (BOOL)escape execute: (BOOL)execute
{
  if (!escape && opcode == 0xbf)
    {
      if (execute)
        {
          unsigned int top = (uint16_t) [self pop];
          uint32_t base = [self popLong], page = [self popLong];
          unsigned int low = 1, high = top / 14, run;
          BOOL found = NO;
          if (page >= [_memory virtualPages] || high < 1)
            [self hardwareError: @"Invalid VMFIND search"];
          while (low <= high)
            {
              unsigned int middle = (low + high) / 2;
              uint32_t start = [_memory readDoubleWord: base + middle * 14];
              if (start > page)
                high = middle - 1;
              else
                low = middle + 1;
            }
          run = high * 14;
          if (high != 0)
            {
              uint32_t start = [_memory readDoubleWord: base + run];
              uint32_t count = [_memory readDoubleWord: base + run + 2];
              found = page == start || (page - start < count);
            }
          [self push: found];
          [self push: found ? run : run + 14];
        }
      return YES;
    }
  if ([self controlOpcode: opcode escape: escape execute: execute] ||
      [self blockOpcode: opcode escape: escape execute: execute] ||
      [self processOpcode: opcode escape: escape execute: execute])
    return YES;
#include "DBInstructionDispatch.inc"
  return NO;
}
@end
