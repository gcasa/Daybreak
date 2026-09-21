/** <title>Draco disk images</title>
    <author name="Daybreak contributors"></author>
    Copyright (c) 2017, Dr. Hans-Walter Latz. See COPYING. */
#ifndef DAYBREAK_DISK_H
#define DAYBREAK_DISK_H
#import <Foundation/Foundation.h>
#include <stdint.h>
/** A validated zlib-compressed Draco disk. Ordinary inputs remain read-only;
    managed Library copies can persist guest writes without altering the seed. */
@interface DBDisk : NSObject
{
  NSMutableData *_sectors;
  NSString *_path;
  NSString *_sourcePath;
  BOOL _workingCopy;
  uint32_t _sectorCount;
  uint16_t _heads, _cylinders;
  BOOL _changed;
}
/** Load a .zdisk and its optional .zdisk.zdelta overlay. Raises DBDiskError
    for corrupt, incomplete or mismatched images. */
- (id) initWithPath: (NSString *)path;
/** Return the user's platform-specific Daybreak hard disk directory. */
+ (NSString *) workingDirectory;
/** Import an image and its delta into a unique private Library copy, or
    reopen an existing managed copy. The selected original is preserved. */
- (id) initWithWorkingCopyOfPath: (NSString *)path;
/** Atomically persist a managed working disk. Ordinary input images are
    never saved by this method. Raises DBDiskError on failure. */
- (void) saveWorkingCopy;
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
/** Atomically export a complete compressed image. Refuses the input and seed
    paths. Managed disks remain dirty until saveWorkingCopy succeeds. */
- (void) saveCopyToPath: (NSString *)path;
@end
#endif
