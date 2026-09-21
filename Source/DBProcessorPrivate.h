/** <title>Internal processor operations</title>
    <author name="Daybreak contributors"></author>
    Copyright (c) 2017, Dr. Hans-Walter Latz. See COPYING.
    AutogsdocSource: DBProcessor.m
    These declarations are private to the instruction implementation. */
#ifndef DAYBREAK_PROCESSOR_PRIVATE_H
#define DAYBREAK_PROCESSOR_PRIVATE_H
#import "DBProcessor.h"
/** Sign extend an eight-bit immediate. */
static inline int32_t
db_sign_byte (uint32_t value)
{
  return (value & 128) ? (int32_t) (value & 255) - 256
                       : (int32_t) (value & 255);
}
/** Sign extend a sixteen-bit immediate. */
static inline int32_t
db_sign_word (uint32_t value)
{
  return (value & 32768) ? (int32_t) (value & 65535) - 65536
                         : (int32_t) (value & 65535);
}
/** Logical shift with zero result for counts outside the word. */
static inline uint16_t
db_shift_word (uint16_t value, int32_t count)
{
  if (count <= -16 || count >= 16)
    return 0;
  return count < 0 ? (uint32_t) value >> -count : (uint32_t) value << count;
}
/** Logical shift with zero result for counts outside the double word. */
static inline uint32_t
db_shift_long (uint32_t value, int32_t count)
{
  if (count <= -32 || count >= 32)
    return 0;
  return count < 0 ? (uint32_t) value >> -count : value << count;
}
/** Rotate a word, reducing the count modulo sixteen. */
static inline uint16_t
db_rotate_word (uint16_t value, int32_t count)
{
  unsigned int n = ((count % 16) + 16) % 16;
  return n == 0 ? value : ((uint32_t) value << n) | (value >> (16 - n));
}
@interface DBProcessor (Private)
/** Peek without discarding, implementing the Java popRecover helper. */
- (int16_t) popRecover;
/** Add the low sixteen bits of pointer to MDS. */
- (uint32_t) lengthenPointer: (uint32_t)pointer;
/** Fetch and advance the byte PC modulo 65536. */
- (uint8_t) nextCodeByte;
/** Fetch two consecutive code bytes, most significant first. */
- (uint16_t) nextCodeWord;
/** Read a word at CB plus the low sixteen bits of offset. */
- (uint16_t) readCode: (uint32_t)offset;
/** Read a word relative to MDS. */
- (uint16_t) readMDSWord: (uint32_t)pointer;
/** Read with sixteen-bit pointer-plus-offset wrapping. */
- (uint16_t) readMDSWord: (uint32_t)pointer offset: (uint32_t)offset;
/** Read a double word after lengthening the pointer. */
- (uint32_t) readMDSDoubleWord: (uint32_t)pointer;
/** Read a double word after wrapping pointer plus offset. */
- (uint32_t) readMDSDoubleWord: (uint32_t)pointer offset: (uint32_t)offset;
/** Store relative to MDS. */
- (void) writeMDSWord: (uint32_t)pointer value: (uint16_t)value;
/** Store with sixteen-bit pointer-plus-offset wrapping. */
- (void) writeMDSWord: (uint32_t)pointer
              offset: (uint32_t)offset
               value: (uint16_t)value;
/** Pop an IEEE single precision bit representation. */
- (float) popFloat;
/** Push an IEEE single precision bit representation. */
- (void) pushFloat: (float)value;
/** Raise a bounds exception. */
- (void) boundsTrap;
/** Raise a nil pointer exception. */
- (void) pointerTrap;
/** Raise a zero divisor exception. */
- (void) divZeroTrap;
/** Raise a quotient overflow exception. */
- (void) divCheckTrap;
/** Raise an invalid instruction operand exception. */
- (void) hardwareError: (NSString *)reason;
/** Query or invoke an opcode.  Returns NO for an unsupported opcode. */
- (BOOL) dispatch: (uint8_t)opcode escape: (BOOL)escape execute: (BOOL)execute;
@end
#import "DBInstructions.h"
#import "DBControl.h"
#import "DBBlocks.h"
#import "DBProcesses.h"
#endif
