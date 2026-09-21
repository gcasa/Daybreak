/** <title>Draco workstation</title>
    <author name="Daybreak contributors"></author>
    Copyright (c) 2017, Dr. Hans-Walter Latz. See COPYING. */
#ifndef DAYBREAK_MACHINE_H
#define DAYBREAK_MACHINE_H
#import "DBProcessor.h"
#import "DBDisk.h"
/** A single-threaded Draco machine with 4 MB RAM, disk, keyboard and an
    832 by 633 monochrome display. Owns a private, writable disk image. */
@interface DBMachine : DBProcessor
{
  DBDisk *_disk;
  BOOL _displayEnabled, _halted;
  uint32_t _lastRetrace;
  uint64_t _diskReads, _diskWrites;
  int32_t _gmtCorrection;
}
/** Load a Draco disk, initialize the IOP, install its germ, and enter sBoot.
    This starts execution at the germ; OS readiness depends on guest progress.
 */
- (id) initWithDisk: (NSString *)path switches: (NSString *)switches;
/** Return the borrowed working disk. */
- (DBDisk *) disk;
/** Return completed disk sector reads. */
- (uint64_t) diskReads;
/** Return completed disk sector writes. */
- (uint64_t) diskWrites;
/** Return YES after the guest requests shutdown or suspension. */
- (BOOL) halted;
/** Return whether the guest has enabled display refresh. */
- (BOOL) displayEnabled;
/** Return packed monochrome scanlines, most significant pixel first. */
- (NSData *) displayData;
/** Update a Level V keyboard bit (0..143); pressed keys are active low. */
- (void) setKey: (unsigned int)key pressed: (BOOL)pressed;
/** Release all keys, for example on focus loss. */
- (void) releaseKeys;
/** Update guest mouse coordinates in display pixels. */
- (void) setMouseX: (uint16_t)x y: (uint16_t)y;
/** Execute a bounded slice, polling device events and process scheduling. */
- (void) runForInstructions: (uint32_t)count;
/** Service a notified IOP device. Unknown device masks raise DBDeviceError. */
- (void) notifyDevice: (uint16_t)mask;
/** Service pending rigid disk requests. */
- (void) serviceDisk;
@end
#endif
