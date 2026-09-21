/* Derived from Dwarf by Dr. Hans-Walter Latz. See COPYING. */
#import "DBProcessorPrivate.h"
#define DB_PDA 0x10000U

static uint16_t
db_next (uint16_t word)
{
  return (word >> 3) & 1023;
}
static uint16_t
db_with_next (uint16_t word, uint16_t index)
{
  return (word & ~0x1ff8) | ((index & 1023) << 3);
}

@implementation DBProcessor (Processes)
- (uint16_t) processWord: (uint16_t)process offset: (unsigned int)offset
{
  if (process < 8 || process >= 1024 || offset >= 8)
    [self hardwareError: @"Invalid process state block"];
  return [_memory readWord: DB_PDA + process * 8 + offset];
}
- (void) setProcessWord: (uint16_t)process
                offset: (unsigned int)offset
                 value: (uint16_t)value
{
  if (process < 8 || process >= 1024 || offset >= 8)
    [self hardwareError: @"Invalid process state block"];
  [_memory writeWord: DB_PDA + process * 8 + offset value: value];
}
- (void) requeue: (uint32_t)source
             to: (uint32_t)destination
        process: (uint16_t)process
{
  uint16_t queue = source ? [_memory readWord: source] : 0;
  uint16_t link = [self processWord: process offset: 0];
  uint16_t previous = 0, current = 0, tail;
  unsigned int remaining = 1024;
  if (db_next (link) != process)
    {
      previous = source ? db_next (queue) : process;
      for (;;)
        {
          if (remaining-- == 0)
            [self hardwareError: @"Cyclic process queue"];
          current = [self processWord: previous offset: 0];
          if (db_next (current) == process)
            break;
          previous = db_next (current);
        }
      [self setProcessWord: previous
                    offset: 0
                     value: db_with_next (current, db_next (link))];
    }
  if (source == 0)
    [self setProcessWord: process
                  offset: 1
                   value: db_with_next ([self processWord: process offset: 1],
                                       db_next (link))];
  else if (db_next (queue) == process)
    [_memory writeWord: source value: db_with_next (queue, previous)];
  queue = [_memory readWord: destination];
  tail = db_next (queue);
  if (tail == 0)
    {
      [self setProcessWord: process
                    offset: 0
                     value: db_with_next (link, process)];
      [_memory writeWord: destination value: db_with_next (queue, process)];
      return;
    }
  previous = tail;
  current = [self processWord: previous offset: 0];
  if ((current >> 13) >= (link >> 13))
    [_memory writeWord: destination value: db_with_next (queue, process)];
  else
    {
      remaining = 1024;
      for (;;)
        {
          uint16_t nextLink;
          if (remaining-- == 0)
            [self hardwareError: @"Unordered process queue"];
          nextLink = [self processWord: db_next (current) offset: 0];
          if ((link >> 13) > (nextLink >> 13))
            break;
          previous = db_next (current);
          current = nextLink;
        }
    }
  [self setProcessWord: process
                offset: 0
                 value: db_with_next (link, db_next (current))];
  [self setProcessWord: previous
                offset: 0
                 value: db_with_next (current, process)];
}
- (void) cleanupCondition: (uint32_t)condition
{
  uint16_t word = [_memory readWord: condition];
  uint16_t process = db_next (word), flags, head;
  unsigned int remaining = 2048;
  if (process == 0)
    return;
  flags = [self processWord: process offset: 1];
  if (db_next (flags) == 0)
    return;
  for (;;)
    {
      if (remaining-- == 0)
        [self hardwareError: @"Cyclic cleanup links"];
      if (db_next (flags) == process)
        {
          [_memory writeWord: condition value: db_with_next (word & ~1, 0)];
          return;
        }
      process = db_next (flags);
      flags = [self processWord: process offset: 1];
      if (db_next (flags) == 0)
        break;
    }
  head = process;
  for (;;)
    {
      uint16_t next;
      if (remaining-- == 0)
        [self hardwareError: @"Cyclic condition queue"];
      next = db_next ([self processWord: process offset: 0]);
      if (next == head)
        break;
      process = next;
    }
  [_memory writeWord: condition value: db_with_next (word, process)];
}
- (void) wakeHead: (uint32_t)condition
{
  uint16_t tail = db_next ([_memory readWord: condition]);
  uint16_t head = db_next ([self processWord: tail offset: 0]);
  [self setProcessWord: head
                offset: 1
                 value: [self processWord: head offset: 1] & ~2];
  [self setProcessWord: head offset: 3 value: 0];
  [self requeue: condition to: DB_PDA process: head];
}
- (BOOL) notifyWakeup: (uint32_t)condition
{
  uint16_t word;
  [self cleanupCondition: condition];
  word = [_memory readWord: condition];
  if (db_next (word) == 0)
    {
      [_memory writeWord: condition value: word | 1];
      return NO;
    }
  [self wakeHead: condition];
  return YES;
}
- (BOOL) exitMonitor: (uint32_t)monitor
{
  uint16_t word = [_memory readWord: monitor];
  if (!(word & 1))
    [self hardwareError: @"Exit of unlocked monitor"];
  [_memory writeWord: monitor value: word & ~1];
  if (db_next (word) == 0)
    return NO;
  [self requeue: monitor
             to: DB_PDA
        process: db_next ([self processWord: db_next (word) offset: 0])];
  return YES;
}
- (void) enterFailed: (uint32_t)monitor
{
  [self setProcessWord: _state.PSB
                offset: 0
                 value: [self processWord: _state.PSB offset: 0] | 4];
  [self requeue: DB_PDA to: monitor process: _state.PSB];
  [self reschedule: NO];
}
- (void) saveProcess: (BOOL)preemption
{
  uint16_t link = [self processWord: _state.PSB offset: 0];
  BOOL permanent = (link & 2) != 0;
  uint32_t state = DB_PDA + [self processWord: _state.PSB offset: 2];
  if (_state.PC > 8)
    [self writeMDSWord: _state.LF - 1 value: _state.PC];
  if (preemption)
    {
      link |= 1;
      if (!permanent)
        {
          uint32_t cell = DB_PDA + 8 + (link >> 13);
          uint16_t offset = [_memory readWord: cell];
          if (offset == 0)
            [self hardwareError: @"No free process state vector"];
          state = DB_PDA + offset;
          [_memory writeWord: cell value: [_memory readWord: state]];
          [self setProcessWord: _state.PSB offset: 2 value: offset];
        }
      [self saveStack: state];
      [_memory writeWord: state + 15 value: _state.LF];
    }
  else
    {
      link &= ~1;
      if (permanent)
        [_memory writeWord: state + 15 value: _state.LF];
      else
        [self setProcessWord: _state.PSB offset: 2 value: _state.LF];
    }
  [self setProcessWord: _state.PSB offset: 0 value: link];
}
- (uint16_t) loadProcess
{
  uint16_t link = [self processWord: _state.PSB offset: 0];
  uint16_t frame = [self processWord: _state.PSB offset: 2];
  uint32_t state = DB_PDA + frame;
  if (link & 1)
    {
      [self loadStack: state];
      frame = [_memory readWord: state + 15];
      if (!(link & 2))
        {
          uint32_t cell = DB_PDA + 8 + (link >> 13);
          [_memory writeWord: state value: [_memory readWord: cell]];
          [_memory writeWord: cell value: state - DB_PDA];
        }
    }
  else
    {
      if (link & 4)
        {
          [self push: 0];
          [self setProcessWord: _state.PSB offset: 0 value: link & ~4];
        }
      if (link & 2)
        frame = [_memory readWord: state + 15];
    }
  _state.MDS = (uint32_t) [self processWord: _state.PSB offset: 4] << 16;
  return frame;
}
- (void) reschedule: (BOOL)preemption
{
  uint16_t tail, process, link;
  unsigned int remaining = 1024;
  if (_state.running)
    [self saveProcess: preemption];
  tail = db_next ([_memory readWord: DB_PDA]);
  process = tail;
  while (tail != 0)
    {
      if (remaining-- == 0)
        [self hardwareError: @"Cyclic ready queue"];
      process = db_next ([self processWord: process offset: 0]);
      link = [self processWord: process offset: 0];
      if ((link & 3) || [_memory readWord: DB_PDA + 8 + (link >> 13)] != 0)
        {
          _state.PSB = process;
          _state.savedPC = _state.PC = 0;
          _state.LF = [self loadProcess];
          _state.running = YES;
          [self transfer: _state.LF source: 0 type: 6 free: NO];
          return;
        }
      if (process == tail)
        break;
    }
  if (_state.WDC != 0)
    [self trap: 3 parameter: 0 words: 0];
  _state.running = NO;
}
- (void) fault: (unsigned int)index
    parameter: (uint32_t)value
        words: (unsigned int)words
{
  uint16_t process = _state.PSB;
  uint32_t queue = DB_PDA + 48 + index * 2, state;
  if (index >= 8)
    [self hardwareError: @"Invalid fault index"];
  [self requeue: DB_PDA to: queue process: process];
  [self notifyWakeup: queue + 1];
  _state.PC = _state.savedPC;
  _state.SP = _state.savedSP;
  [self reschedule: YES];
  state = DB_PDA + [self processWord: process offset: 2];
  if (words > 0)
    [_memory writeWord: state + 16 value: value];
  if (words > 1)
    [_memory writeWord: state + 17 value: value >> 16];
  [NSException raise: @"DBMesaAbort" format: @"Process fault"];
}
- (void) requestInterrupt: (uint16_t)mask
{
  _state.WP |= mask;
}
- (void) pollProcesses
{
  BOOL changed = NO;
  uint16_t pending;
  uint32_t now;
  unsigned int i, count;
  if (_state.WDC != 0)
    return;
  pending = _state.WP;
  _state.WP = 0;
  for (i = 0; i < 16; i++)
    if (pending & (1U << i))
      changed |= [self notifyWakeup: DB_PDA + 16 + (15 - i) * 2];
  now = [self intervalTimer];
  if ((uint32_t) (now - _lastPulse) > 3200)
    {
      _lastPulse = now;
      if (++_state.PTC == 0)
        _state.PTC = 1;
      count = [_memory readWord: DB_PDA + 1];
      if (count > 1016)
        [self hardwareError: @"Invalid process count"];
      for (i = 8; i < 8 + count; i++)
        if ([self processWord: i offset: 3] == _state.PTC)
          {
            [self setProcessWord: i
                          offset: 1
                           value: [self processWord: i offset: 1] & ~2];
            [self setProcessWord: i offset: 3 value: 0];
            [self requeue: 0 to: DB_PDA process: i];
            changed = YES;
          }
    }
  if (changed)
    [self reschedule: YES];
}
- (BOOL) processOpcode: (uint8_t)opcode escape: (BOOL)escape execute: (BOOL)execute
{
  BOOL supported = escape ? ((opcode >= 2 && opcode <= 6)
                             || (opcode >= 15 && opcode <= 17))
                          : (opcode == 0xf1 || opcode == 0xf2);
  uint32_t monitor, condition, source;
  uint16_t word, flags, timeout, process;
  BOOL changed;
  if (!supported || !execute)
    return supported;
  if (!escape)
    {
      monitor = (uint32_t) [self popLong];
      [self checkEmptyStack];
      if (opcode == 0xf2)
        {
          if ([self exitMonitor: monitor])
            [self reschedule: NO];
        }
      else
        {
          word = [_memory readWord: monitor];
          if (word & 1)
            [self enterFailed: monitor];
          else
            {
              [_memory writeWord: monitor value: word | 1];
              [self push: 1];
            }
        }
      return YES;
    }
  switch (opcode)
    {
    case 2:
      timeout = [self pop];
      condition = [self popLong];
      monitor = [self popLong];
      [self checkEmptyStack];
      [self cleanupCondition: condition];
      changed = [self exitMonitor: monitor];
      flags = [self processWord: _state.PSB offset: 1];
      word = [_memory readWord: condition];
      if (!(flags & 1) || !(word & 2))
        {
          if (word & 1)
            [_memory writeWord: condition value: word & ~1];
          else
            {
              if (timeout != 0)
                {
                  timeout += _state.PTC;
                  if (timeout == 0)
                    timeout = 1;
                }
              [self setProcessWord: _state.PSB offset: 3 value: timeout];
              [self setProcessWord: _state.PSB offset: 1 value: flags | 2];
              [self requeue: DB_PDA to: condition process: _state.PSB];
              changed = YES;
            }
        }
      if (changed)
        [self reschedule: NO];
      break;
    case 3:
      condition = [self popLong];
      monitor = [self popLong];
      [self checkEmptyStack];
      word = [_memory readWord: monitor];
      if (word & 1)
        [self enterFailed: monitor];
      else
        {
          [self cleanupCondition: condition];
          flags = db_with_next ([self processWord: _state.PSB offset: 1], 0);
          [self setProcessWord: _state.PSB offset: 1 value: flags];
          if ((flags & 1) && ([_memory readWord: condition] & 2))
            [self trap: 13 parameter: 0 words: 0];
          [_memory writeWord: monitor value: word | 1];
          [self push: 1];
        }
      break;
    case 4:
    case 5:
      condition = [self popLong];
      [self checkEmptyStack];
      [self cleanupCondition: condition];
      changed = NO;
      while (db_next ([_memory readWord: condition]) != 0)
        {
          [self wakeHead: condition];
          changed = YES;
          if (opcode == 4)
            break;
        }
      if (changed)
        [self reschedule: NO];
      break;
    case 6:
      process = (uint16_t) [self pop] / 8;
      condition = [self popLong];
      source = [self popLong];
      [self checkEmptyStack];
      [self requeue: source to: condition process: process];
      [self reschedule: NO];
      break;
    case 15:
      word = [self pop];
      [self checkEmptyStack];
      flags = [self processWord: _state.PSB offset: 0];
      [self setProcessWord: _state.PSB
                    offset: 0
                     value: (flags & 0x1fff) | ((word & 7) << 13)];
      [self requeue: DB_PDA to: DB_PDA process: _state.PSB];
      [self reschedule: NO];
      break;
    case 16:
      if (_state.WDC == 64)
        [self trap: 12 parameter: 0 words: 0];
      _state.WDC++;
      break;
    case 17:
      if (_state.WDC == 0)
        [self trap: 12 parameter: 0 words: 0];
      _state.WDC--;
      break;
    }
  return YES;
}
@end
