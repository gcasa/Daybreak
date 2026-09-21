/** <title>Daybreak Mesa processor</title>
    <author name="Daybreak contributors"></author>
    <abstract>A manually managed Objective-C Mesa execution engine.</abstract>
    Copyright (c) 2017, Dr. Hans-Walter Latz.  See COPYING.
 */
#ifndef DAYBREAK_PROCESSOR_H
#define DAYBREAK_PROCESSOR_H
#import "DBMemory.h"
/** Number of evaluation-stack words specified by Mesa PrincOps. */
#define DB_STACK_LENGTH 14
/** <ignore> */
struct DBProcessorState
{
  uint32_t CB, MDS, GF32;
  uint16_t PC, savedPC, LF, GF16, GFI;
  uint16_t PSB, PTC, WDC, WP, XTS, MP;
  uint8_t breakByte;
  unsigned int savedSP;
  BOOL running;
  uint16_t stack[DB_STACK_LENGTH];
  unsigned int SP;
  uint64_t instructions;
};
/** </ignore> */
/** Processor state.  PC and savedPC are byte offsets within CB; CB, MDS and
    GF32 are word addresses.  GF16 and LF are MDS-relative word pointers.
    PSB indexes the PDA; PTC and IT are independent timeout and interval
   clocks. Modify only while the processor is stopped. */
typedef struct DBProcessorState DBProcessorState;

/** A Mesa processor with independent registers, stack and retained memory.
    Uses explicit retain/release and Objective-C 1.0 syntax.  One instance is
    confined to one thread.  The implemented opcode coverage is listed in
    Documentation/PORTING.md.  Unimplemented instructions raise DBOpcodeTrap
    or DBEscapeOpcodeTrap; no instruction is silently treated as a no-op.
    Guest trap delivery is enabled explicitly by the machine boot loader. */
@interface DBProcessor : NSObject
{
  DBMemory *_memory;
  DBProcessorState _state;
  BOOL _post40;
  unsigned int _displayDepth;
  uint32_t _displayVirtualStart, _displayVirtualEnd;
  BOOL _guestTraps;
  NSMutableDictionary *_bitBlts;
  uint32_t _nextBitBlt;
  unsigned int _trapDepth;
  uint32_t _timerBase, _timerOffset, _lastPulse;
}
/** Retain memory and initialize a processor.  post40 selects the changed
    chapters global-frame instructions; NO selects PrincOps 4.0. */
- (id) initWithMemory: (DBMemory *)memory post40: (BOOL)post40;
/** Return retained engine memory as a borrowed reference. */
- (DBMemory *) memory;
/** Return a borrowed pointer to registers, valid for the instance lifetime. */
- (DBProcessorState *) state;
/** Clear registers and stack, preserving memory and the instruction-set mode.
 */
- (void) reset;
/** Execute one instruction or one restartable block unit. Diagnostic mode
    restores registers and stack on exceptions; guest mode dispatches traps
    and faults to Pilot and preserves scheduler changes. Memory writes are
    never rolled back. Successful execution units advance instructions. */
- (void) step;
/** Execute at most count units. Guest mode polls interrupts and timeouts;
    returns early when no process is runnable. Call again to resume after
    device events. Zero performs no work. */
- (void) runForInstructions: (uint32_t)count;
/** Push a word or raise DBStackError when full. */
- (void) push: (uint16_t)value;
/** Pop a signed word or raise DBStackError when empty. */
- (int16_t) pop;
/** Push low then high word, checking space before changing the stack. */
- (void) pushLong: (uint32_t)value;
/** Pop a signed double word, checking depth before changing the stack. */
- (int32_t) popLong;
/** Make the most recently discarded slot active again, as Mesa REC does.
    Recover checks capacity, not the historical contents of the slot. */
- (void) recover;
/** Discard the top word without erasing it. */
- (void) discard;
/** Return whether a primary or escape opcode has an implementation in this
 * mode. */
- (BOOL) supportsOpcode: (uint8_t)opcode escape: (BOOL)escape;
@end
#endif
