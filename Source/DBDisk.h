/** <title>Draco disk images</title>
    <author name="Daybreak contributors"></author>
    Copyright (c) 2017, Dr. Hans-Walter Latz. See COPYING. */
#ifndef DAYBREAK_DISK_H
#define DAYBREAK_DISK_H
#import <Foundation/Foundation.h>
#include <stdint.h>
/** A validated zlib-compressed Draco disk. Changes are kept in memory until
    explicitly exported to a new image; the input file is never overwritten. */
@interface DBDisk : NSObject
{
  NSMutableData *_sectors;
  NSString *_path;
  uint32_t _sectorCount;
  uint16_t _heads, _cylinders;
  BOOL _changed;
}
/** Load a .zdisk and its optional .zdisk.zdelta overlay. Raises DBDiskError
    for corrupt, incomplete or mismatched images. */
- (id) initWithPath: (NSString *)path;
/** Return the borrowed input path. */
- (NSString *) path;
/** Return the number of heads. */
- (uint16_t) heads;
/** Return the number of cylinders. */
- (uint16_t) cylinders;
/** Return the sector count (16 sectors per track). */
- (uint32_t) sectorCount;
/** Read a sector word. Offsets 0..9 are labels and 10..265 are data. */
- (uint16_t) wordAtSector: (uint32_t)sector offset: (unsigned int)offset;
/** Change a sector word in the private working image. */
- (void) writeSector: (uint32_t)sector
             offset: (unsigned int)offset
              value: (uint16_t)value;
/** Extract the contiguous, labelled germ from the physical volume root. */
- (NSData *) germ;
/** Return YES after any sector modification. */
- (BOOL) changed;
/** Atomically export a complete compressed image. Refuses the input path. */
- (void) saveCopyToPath: (NSString *)path;
@end
#endif
