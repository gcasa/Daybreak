/** <title>Draco floppy media</title>
    <author name="Daybreak contributors"></author>
    Derived from Dwarf by Dr. Hans-Walter Latz. See COPYING. */
#ifndef DAYBREAK_FLOPPY_H
#define DAYBREAK_FLOPPY_H
#import <Foundation/Foundation.h>
/** A private floppy working copy with cylinder/head/sector addressing.
    Loads ImageDisk (.imd), DMK (.dmk) standard raw (.img/.raw), and SCP MFM
   flux media, including mixed sector sizes and nonsequential sector numbering.
   DMK header protection and the explicit readOnly option are honored. Exports
   never overwrite the input file. All methods require serialization by the
   caller. */
@interface DBFloppy : NSObject
{
  NSString *_path;
  NSMutableDictionary *_sectors, *_kinds, *_modes;
  unsigned int _cylinders, _heads;
  BOOL _readOnly, _changed;
}
/** Load and validate an image; malformed/truncated files raise DBFloppyError.
    readOnly additionally protects media from guest writes. DMK CRC errors
    and SCP CRC errors remain visible as guest data errors. SCP is decoded
    to sectors; original timing and weak-bit behavior are not emulated. */
- (id) initWithPath: (NSString *)path readOnly: (BOOL)readOnly;
/** Return the borrowed original image path. */
- (NSString *) path;
/** Return the number of cylinders represented by the image. */
- (unsigned int) cylinders;
/** Return one or two heads. */
- (unsigned int) heads;
/** Return the number of sectors on a track (zero for absent tracks). */
- (unsigned int) sectorsAtCylinder: (unsigned int)cylinder
                             head: (unsigned int)head;
/** Return ascending sector IDs on a track, in an autoreleased array. */
- (NSArray *) sectorIDsAtCylinder: (unsigned int)cylinder
                            head: (unsigned int)head;
/** Return borrowed immutable bytes, or nil if the sector is missing.
    Cylinder/head are zero-based, sector IDs are one-based. */
- (NSData *) sectorAtCylinder: (unsigned int)cylinder
                        head: (unsigned int)head
                      sector: (unsigned int)sector;
/** Return Pilot status: 1 good, 5 deleted data, 6 unavailable, 8 CRC error. */
- (unsigned int) statusAtCylinder: (unsigned int)cylinder
                            head: (unsigned int)head
                          sector: (unsigned int)sector;
/** Replace an existing sector with equally sized data and its deleted mark.
    Return Pilot status, including 10 for write-protected media. */
- (unsigned int) writeCylinder: (unsigned int)cylinder
                         head: (unsigned int)head
                       sector: (unsigned int)sector
                         data: (NSData *)data
                      deleted: (BOOL)deleted;
/** Format an existing track from four-byte C/H/R/N records and a fill byte.
    Return Pilot status; validates all records before modifying any sector. */
- (unsigned int) formatCylinder: (unsigned int)cylinder
                          head: (unsigned int)head
                   descriptors: (NSData *)descriptors
                          fill: (unsigned char)fill;
/** Return YES when guest writes are prohibited. */
- (BOOL) readOnly;
/** Return YES after a write/format until successful export. */
- (BOOL) changed;
/** Atomically export IMD, DMK or raw media to a separate path and clear
   changed. The extension selects the format. Raw export rejects lossy
   conversions; DMK export regenerates MFM tracks and CRCs. Raises
   DBFloppyError on failure. */
- (void) saveCopyToPath: (NSString *)path;
@end
#endif
