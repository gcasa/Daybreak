/** <title>Mesa control transfers</title>
    <author name="Daybreak contributors"></author>
    Copyright (c) 2017, Dr. Hans-Walter Latz. See COPYING. */
#ifndef DAYBREAK_CONTROL_H
#define DAYBREAK_CONTROL_H
#import "DBProcessor.h"
/** Frame allocation, calls, traps and architectural stack vectors. */
@interface DBProcessor (Control)
/** Allocate an AV frame, following indirect size entries. */
- (uint16_t) allocateFrame: (uint16_t)index;
/** Return a frame to its AV free list. */
- (void) freeFrame: (uint16_t)frame;
/** Resolve a backward global or code link. */
- (uint32_t) fetchLink: (uint8_t)offset;
/** Transfer to a tagged control link. Types are return=0, call=1,
    local=2, port=3, transfer=4, trap=5 and process=6. */
- (void) transfer: (uint32_t)destination
          source: (uint16_t)source
            type: (unsigned int)type
            free: (BOOL)releaseFrame;
/** Save caller PC and invoke a procedure. */
- (void) call: (uint32_t)destination;
/** Apply the transfer trap shift register after a successful transfer. */
- (void) checkTransferTrap: (uint32_t)destination type: (unsigned int)type;
/** Store all stack slots, depth and break byte in a state vector; empty stack.
 */
- (void) saveStack: (uint32_t)address;
/** Restore stack slots, depth and break byte from a state vector. */
- (void) loadStack: (uint32_t)address;
/** Enable Pilot trap delivery; disabled by default for diagnostic execution.
 */
- (void) setGuestTraps: (BOOL)enabled;
/** Invoke an SD trap and store zero, one or two parameter words. */
- (void) trap: (unsigned int)index
    parameter: (uint32_t)value
        words: (unsigned int)words;
/** Dispatch control/register instructions; execute=NO only queries coverage.
 */
- (BOOL) controlOpcode: (uint8_t)opcode
               escape: (BOOL)escape
              execute: (BOOL)execute;
/** Read the wrapping interval timer (one pulse per 16 microseconds). */
- (uint32_t) intervalTimer;
/** Change the interval timer origin. */
- (void) setIntervalTimer: (uint32_t)value;
/** Reject a nonempty evaluation stack at a scheduling instruction. */
- (void) checkEmptyStack;
/** Convert a diagnostic exception into a guest trap or fault, if enabled. */
- (BOOL) deliverException: (NSException *)exception opcode: (uint8_t)opcode;
/** Deliver a trap, including faults raised while entering its handler. */
- (void) dispatchException: (NSException *)exception opcode: (uint8_t)opcode;
@end
#endif
