/** <title>Restartable Mesa block operations</title>
    <author name="Daybreak contributors"></author>
    Copyright (c) 2017, Dr. Hans-Walter Latz. See COPYING. */
#ifndef DAYBREAK_BLOCKS_H
#define DAYBREAK_BLOCKS_H
#import "DBProcessor.h"
/** Restartable word and byte transfers, comparisons and checksums. */
@interface DBProcessor (Blocks)
/** Execute one unit of a block operation and leave continuation operands on
    the stack when more work remains. This bounds interrupt latency and
    preserves progress across page faults. execute=NO queries coverage. */
- (BOOL) blockOpcode: (uint8_t)opcode escape: (BOOL)escape execute: (BOOL)execute;
/** Execute one restartable trapezoid scanline using 16.16 edge interpolators.
 */
- (void) trapZBlt;
/** Execute one monochrome or indexed-color BITBLT, COLORBLT or BITBLTX
    scanline, retaining continuation state across process switches and faults. */
- (void) bitBlt: (uint8_t)opcode;
@end
#endif
