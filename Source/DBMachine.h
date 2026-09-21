/** <title>Draco workstation</title>
    <author name="Daybreak contributors"></author>
    Copyright (c) 2017, Dr. Hans-Walter Latz. See COPYING. */
#ifndef DAYBREAK_MACHINE_H
#define DAYBREAK_MACHINE_H
#import "DBProcessor.h"
#import "DBDisk.h"
#import "DBNetwork.h"
#import "DBFloppy.h"
/** A single-threaded Draco machine with 4 MB RAM, disk, keyboard and an
    832 by 633 monochrome display. Owns a private, writable disk image. */
@interface DBMachine : DBProcessor
{
  DBDisk *_disk;
  DBFloppy *_floppy, *_pendingFloppy;
  DBNetwork *_network;
  NSMutableArray *_receiveIOCBs;
  BOOL _receiveStopped;
  uint32_t _lastDevicePoll, _insertFloppyAt;
  uint16_t _hostID[3];
  uint64_t _packetsSent, _packetsReceived;
  BOOL _displayEnabled, _halted;
  uint32_t _lastRetrace;
  uint64_t _diskReads, _diskWrites;
  int32_t _gmtCorrection;
}
/** Load a Draco disk, initialize the IOP, install its germ, and enter sBoot.
    This starts execution at the germ; OS readiness depends on guest progress.
 */
- (id) initWithDisk: (NSString *)path switches: (NSString *)switches;
/** Boot a private Library disk when workingCopy is YES; otherwise use an
    in-memory image suitable for isolated tests. */
- (id) initWithDisk: (NSString *)path switches: (NSString *)switches
       workingCopy: (BOOL)working;
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

/** Draco removable media and NetHub Ethernet IOP services. */
@interface DBMachine (Devices)
/** Return the borrowed current floppy, or nil while the drive is empty. */
- (DBFloppy *) floppy;
/** Insert IMD/DMK media. Replacement preserves a 500 ms door-open interval.
    Raises DBFloppyError if changed media would be discarded; export or eject
    explicitly first. Loading failure leaves the old medium in place. */
- (void) insertFloppy: (NSString *)path readOnly: (BOOL)readOnly;
/** Eject media, refusing unsaved changes unless discard is YES. */
- (void) ejectFloppyDiscardingChanges: (BOOL)discard;
/** Connect/reconnect to NetHub; nil host disconnects. No default connection.
 */
- (void) setNetworkHost: (NSString *)host port: (unsigned int)port;
/** Set a six-byte unicast Ethernet ID before boot. Twelve hexadecimal digits,
    optionally separated by colons or hyphens; invalid IDs raise an exception.
    The default ID preserves the reference ViewPoint configuration. */
- (void) setHostID: (NSString *)identifier;
/** Return the borrowed transport or nil when networking is disabled. */
- (DBNetwork *) network;
/** Return accepted outgoing frame count. */
- (uint64_t) packetsSent;
/** Return frames delivered to guest receive buffers. */
- (uint64_t) packetsReceived;
/** Poll transport, waiting receive IOCBs and delayed media changes. Runs even
    when the CPU is idle; caller must serialize with instruction execution. */
- (void) pollDevices;
/** Process the specified Ethernet input/output notification queue. */
- (void) serviceNetwork: (BOOL)input;
/** Complete queued floppy controller requests and raise client interrupts. */
- (void) serviceFloppy;
@end
#endif
