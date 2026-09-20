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
  uint16_t PC, savedPC, LF, GF16;
  uint16_t stack[DB_STACK_LENGTH];
  unsigned int SP;
  uint64_t instructions;
};
/** </ignore> */
/** Processor state.  PC and savedPC are byte offsets within CB; CB, MDS and
    GF32 are word addresses.  GF16 and LF are MDS-relative word pointers.
    Modify only while the processor is stopped. */
typedef struct DBProcessorState DBProcessorState;

/** A Mesa processor with independent registers, stack and retained memory.
    Uses explicit retain/release and Objective-C 1.0 syntax.  One instance is
    confined to one thread.  The implemented opcode coverage is listed in
    Documentation/PORTING.md.  Unimplemented instructions raise DBOpcodeTrap
    or DBEscapeOpcodeTrap; no instruction is silently treated as a no-op.
    Architectural traps currently report host exceptions rather than invoking
    Pilot trap handlers, so this engine cannot yet boot a workstation OS. */
@interface DBProcessor : NSObject
{
  DBMemory *_memory;
  DBProcessorState _state;
  BOOL _post40;
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
/** Execute one instruction.  On exception restore PC and the complete stack
    to their pre-instruction state.  Completed memory writes are not rolled
    back.  The instruction count advances only on successful completion. */
- (void) step;
/** Execute exactly count instructions, stopping immediately on an exception.
    Zero performs no work.  The caller controls scheduling and cancellation. */
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
