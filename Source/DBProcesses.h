/** <title>Mesa process scheduling</title>
    <author name="Daybreak contributors"></author>
    Copyright (c) 2017, Dr. Hans-Walter Latz. See COPYING. */
#ifndef DAYBREAK_PROCESSES_H
#define DAYBREAK_PROCESSES_H
#import "DBProcessor.h"
/** Per-processor priority queues, monitors, interrupts, faults and timeouts.
    Call these methods on the same thread as instruction execution. */
@interface DBProcessor (Processes)
/** Read a word in a process state block, validating the index. */
- (uint16_t) processWord: (uint16_t)process offset: (unsigned int)offset;
/** Update a word in a process state block. */
- (void) setProcessWord: (uint16_t)process
                offset: (unsigned int)offset
                 value: (uint16_t)value;
/** Move a process between circular priority queues. A zero source removes
    a timed-out waiter and preserves a cleanup link. */
- (void) requeue: (uint32_t)source
             to: (uint32_t)destination
        process: (uint16_t)process;
/** Remove timeout cleanup links from a condition queue. */
- (void) cleanupCondition: (uint32_t)condition;
/** Wake the highest-priority waiter. The condition must not be empty. */
- (void) wakeHead: (uint32_t)condition;
/** Notify a device condition, remembering a wakeup when no process waits. */
- (BOOL) notifyWakeup: (uint32_t)condition;
/** Unlock a monitor, returning YES when a waiting process became ready. */
- (BOOL) exitMonitor: (uint32_t)monitor;
/** Queue the current process on a locked monitor and reschedule. */
- (void) enterFailed: (uint32_t)monitor;
/** Select the highest-priority runnable process, saving the current context.
    Preemption additionally saves the evaluation stack. */
- (void) reschedule: (BOOL)preemption;
/** Save the current process context for a voluntary or preemptive switch. */
- (void) saveProcess: (BOOL)preemption;
/** Restore the selected process and return its local frame. */
- (uint16_t) loadProcess;
/** Queue a fault, notify its handler, and save one or two parameter words. */
- (void) fault: (unsigned int)index
    parameter: (uint32_t)value
        words: (unsigned int)words;
/** OR device interrupt bits into the wakeup register. */
- (void) requestInterrupt: (uint16_t)mask;
/** Deliver enabled interrupts and advance the timeout clock between
 * instructions. */
- (void) pollProcesses;
/** Dispatch chapter 10 instructions; execute=NO only queries coverage. */
- (BOOL) processOpcode: (uint8_t)opcode
               escape: (BOOL)escape
              execute: (BOOL)execute;
@end
#endif
