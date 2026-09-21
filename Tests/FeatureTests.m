/* Workstation configuration and extended instruction regressions. See COPYING.
 */
#import "DBDuchess.h"
#import "DBProcessorPrivate.h"
#import "DBBlocks.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <zlib.h>
static unsigned int checks;
#define CHECK(x)                                                              \
  do                                                                          \
    {                                                                         \
      checks++;                                                               \
      if (!(x))                                                               \
        {                                                                     \
          fprintf (stderr, "FAIL %d: %s\n", __LINE__, #x);                    \
          exit (1);                                                           \
        }                                                                     \
    }                                                                         \
  while (0)
static void
put_long (DBMemory *m, uint32_t address, uint32_t value)
{
  [m writeWord: address value: value];
  [m writeWord: address + 1 value: value >> 16];
}
/* Encode a regenerated DMK track into SCP flux intervals. This independent
   encoder retains missing-clock A1 marks and produces exact 250 kbit/s MFM. */
static void
store_le32 (unsigned char *p, uint32_t value)
{
  unsigned int i;
  for (i = 0; i < 4; i++)
    p[i] = value >> (i * 8);
}
static NSData *
scp_from_dmk (NSData *dmk)
{
  const unsigned char *p = [dmk bytes];
  unsigned int length = p[2] | (p[3] << 8), i, bit, previous = 0, cells = 0;
  NSMutableData *flux = [NSMutableData data];
  NSMutableData *result = [NSMutableData dataWithLength: 704];
  unsigned char *header;
  for (i = 128; i < length; i++)
    {
      unsigned int byte = p[16 + i], word = 0;
      BOOL sync
          = byte == 0xa1
            && ((i + 2 < length && p[17 + i] == 0xa1 && p[18 + i] == 0xa1)
                || (i > 128 && i + 1 < length && p[15 + i] == 0xa1
                    && p[17 + i] == 0xa1)
                || (i > 129 && p[14 + i] == 0xa1 && p[15 + i] == 0xa1));
      for (bit = 0; bit < 8; bit++)
        {
          unsigned int current = (byte >> (7 - bit)) & 1;
          word = (word << 2) | ((!previous && !current) << 1) | current;
          previous = current;
        }
      if (sync)
        word = 0x4489;
      for (bit = 0; bit < 16; bit++)
        {
          cells++;
          if (word & (0x8000 >> bit))
            {
              unsigned int ticks = cells * 80;
              unsigned char sample[2] = { ticks >> 8, ticks };
              [flux appendBytes: sample length: 2];
              cells = 0;
            }
        }
    }
  header = [result mutableBytes];
  memcpy (header, "SCP", 3);
  header[3] = 0x25;
  header[5] = 1;
  header[8] = 16;
  store_le32 (header + 16, 688);
  memcpy (header + 688, "TRK", 3);
  store_le32 (header + 692, 8000000);
  store_le32 (header + 696, [flux length] / 2);
  store_le32 (header + 700, 16);
  [result appendData: flux];
  return result;
}
int
main (int argc, char **argv)
{
#ifdef GNUSTEP
  extern char **environ;
  GSInitializeProcess (argc, argv, environ);
#else
  (void) argc;
  (void) argv;
#endif
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  NSString *directory = [NSTemporaryDirectory ()
      stringByAppendingPathComponent: [[NSProcessInfo processInfo]
                                         globallyUniqueString]];
  NSString *path = [directory stringByAppendingPathComponent: @"pilot.dsk"];
  NSMutableData *raw = [NSMutableData dataWithLength: 16384];
  DBDuchess *machine;
  DBMemory *m;
  uint32_t disk, display, processor;
  unsigned int i;
  [[NSFileManager defaultManager] createDirectoryAtPath: directory
                            withIntermediateDirectories: YES
                                             attributes: nil
                                                  error: NULL];
  ((unsigned char *) [raw mutableBytes])[0] = 0xa2;
  ((unsigned char *) [raw mutableBytes])[1] = 0x8a;
  CHECK ([raw writeToFile: path atomically: YES]);
  machine = [[DBDuchess alloc] initWithDisk: path
                                      width: 1152
                                     height: 861
                                      color: YES
                                workingCopy: NO];
  m = [machine memory];
  CHECK ([machine displayWidth] == 1152 && [machine displayHeight] == 861);
  CHECK ([m realPageForPage: 128] == 0 && [m realPageForPage: 1] == 129);
  CHECK ([m flagsForPage: 8192] == DB_MAP_VACANT);
  /* MAPDISPLAY uses a trailing block count, not a count >= total pages. */
  {
    unsigned int pages = (768 * 861 + 255) / 256;
    [machine pushLong: 10000];
    [machine pushLong: 8192];
    [machine push: pages];
    [machine push: 3];
    CHECK ([machine dispatch: 0x8a escape: YES execute: YES]);
    CHECK ([m realPageForPage: 10003 - pages] == 8192);
    CHECK ([m realPageForPage: 10002] == 8192 + pages - 1);
  }
  disk = [m readDoubleWord: 0x8002];
  display = [m readDoubleWord: 0x8018];
  processor = [m readDoubleWord: 0x8010];
  CHECK ([m readWord: disk + 7] == 1 && [m readWord: disk + 8] == 2);
  CHECK ([m readDoubleWord: processor + 6] == 8192);
  CHECK ([m readWord: display + 37] == 2);
  [m writeWord: display value: 1];
  [m writeWord: display + 36 value: 42];
  [m writeWord: display + 4 value: 0x3412];
  [m writeWord: display + 5 value: 0x56];
  [machine callAgent: 12];
  [m writePhysicalWord: 8192 * 256 value: 0x2a00];
  {
    NSData *rgb = [machine displayRGB];
    const unsigned char *bytes = [rgb bytes];
    CHECK ([rgb length] == 1152 * 861 * 3);
    CHECK (bytes[0] == 0x12 && bytes[1] == 0x34 && bytes[2] == 0x56);
  }
  [m writeWord: display + 36 value: 256];
  [machine callAgent: 12];
  CHECK ([m readWord: display + 1] == 2);
  [m writeWord: display value: 4];
  [m writeWord: display + 14 value: 0x8000];
  [machine callAgent: 12];
  CHECK (((const uint16_t *) [[machine cursorData] bytes])[0] == 0x8000);
  [machine callAgent: 6];
  CHECK ([machine beepSerial] == 1);
  [machine setKey: 37 pressed: YES];
  CHECK (([m readWord: [m readDoubleWord: 0x800a] + 2] & 0x400) == 0);
  [machine releaseKeys];
  CHECK ([m readWord: [m readDoubleWord: 0x800a] + 2] == 65535);
  put_long (m, disk, 0x2000);
  put_long (m, 0x2010, 0x3000);
  [m writeWord: 0x2013 value: 1];
  [m writeWord: 0x2014 value: 1];
  [machine callAgent: 1];
  CHECK ([m readWord: 0x2015] == 1 && [m readWord: 0x3000] == 0xa28a);
  [m writeWord: 0x3000 value: 0xbeef];
  [m writeWord: 0x2013 value: 2];
  [m writeWord: 0x2014 value: 1];
  [machine callAgent: 1];
  CHECK ([[machine disk] wordAtSector: 0 offset: 10] == 0xbeef);
  CHECK ([[NSData dataWithContentsOfFile: path] isEqual: raw]);
  [m writeWord: 0x2013 value: 4];
  [m writeWord: 0x2014 value: 1];
  [machine callAgent: 1];
  CHECK ([[machine disk] wordAtSector: 0 offset: 10] == 0);
  put_long (m, 0x400e, 10);
  put_long (m, 0x4010, 5);
  put_long (m, 0x401c, 20);
  put_long (m, 0x401e, 3);
  for (i = 0; i < 4; i++)
    {
      static const unsigned int pages[4] = { 9, 10, 14, 15 };
      [machine pushLong: pages[i]];
      [machine pushLong: 0x4000];
      [machine push: 28];
      CHECK ([machine dispatch: 0xbf escape: NO execute: YES]);
      CHECK ((uint16_t) [machine pop] == (i == 3 ? 28 : 14));
      CHECK ([machine pop] == (i == 1 || i == 2));
    }
  put_long (m, 0x5000, 0x6000);
  [m writeWord: 0x5003 value: 16];
  put_long (m, 0x5004, 0x6100);
  [m writeWord: 0x6100 value: 65535];
  put_long (m, 0x5008, 2U << 16);
  put_long (m, 0x500a, 1U << 16);
  put_long (m, 0x500c, 6U << 16);
  put_long (m, 0x500e, 1U << 16);
  [m writeWord: 0x5010 value: 2];
  [machine pushLong: 0x5000];
  [machine trapZBlt];
  CHECK ([m readWord: 0x6000] == 0x3c00 && [machine state]->SP == 3);
  [machine trapZBlt];
  CHECK ([m readWord: 0x6001] == 0x1e00 && [machine state]->SP == 0);
  /* COLORBLT expands monochrome pixels through the guest color map. */
  put_long (m, 0x7000, 0x7200);
  [m writeWord: 0x7002 value: 0];
  [m writeWord: 0x7003 value: 2];
  put_long (m, 0x7004, 0x7100);
  [m writeWord: 0x7006 value: 0];
  [m writeWord: 0x7007 value: 2];
  [m writeWord: 0x7008 value: 2];
  [m writeWord: 0x7009 value: 1];
  [m writeWord: 0x700a value: 0x2000];
  [m writeWord: 0x700b value: 0x12];
  [m writeWord: 0x700c value: 0x34];
  [m writeWord: 0x7100 value: 0x8000];
  [machine push: 0x7000];
  [machine bitBlt: 0xc0];
  CHECK ([m readWord: 0x7200] == 0x3412);
  {
    DBNetwork *network = [[DBNetwork alloc] initWithHost: @"local" port: 3333];
    NSMutableData *request = [NSMutableData dataWithLength: 54];
    unsigned char *bytes = [request mutableBytes];
    NSData *reply;
    CHECK ([network connected]);
    bytes[12] = 6;
    bytes[17] = 40;
    bytes[19] = 4;
    bytes[31] = 8;
    bytes[49] = 1;
    bytes[51] = 2;
    bytes[53] = 1;
    bytes[44] = 0x12;
    bytes[45] = 0x34;
    CHECK ([network sendPacket: request]);
    reply = [network receivePacket];
    CHECK ([reply length] == 74);
    CHECK (((const unsigned char *) [reply bytes])[44] == 0x12);
    CHECK (((const unsigned char *) [reply bytes])[53] == 2);
    CHECK ([network receiveLoopbackPacket: request]);
    CHECK ([[network receivePacket] isEqual: request]);
    CHECK (![network receiveLoopbackPacket: [NSData data]]);
    [network close];
    CHECK (![network connected]);
    [network release];
  }
  {
    NSString *floppyPath =
        [directory stringByAppendingPathComponent: @"floppy.img"];
    NSString *dmk = [directory stringByAppendingPathComponent: @"floppy.dmk"];
    NSMutableData *media = [NSMutableData dataWithLength: 737280];
    DBFloppy *floppy, *reloaded;
    ((unsigned char *) [media mutableBytes])[0] = 42;
    CHECK ([media writeToFile: floppyPath atomically: YES]);
    floppy = [[DBFloppy alloc] initWithPath: floppyPath readOnly: NO];
    CHECK ([floppy cylinders] == 80 && [floppy heads] == 2);
    [machine insertFloppy: floppyPath readOnly: YES];
    [m writePhysicalWord: 0x22a7 value: 0x1234];
    [machine ejectFloppyDiscardingChanges: NO];
    CHECK ([m physicalWord: 0x22a7] == 0x1234);
    CHECK ([m readWord: [m readDoubleWord: 0x8004] + 10] == 0);
    [floppy saveCopyToPath: dmk];
    reloaded = [[DBFloppy alloc] initWithPath: dmk readOnly: NO];
    CHECK (![reloaded readOnly]);
    CHECK ([reloaded statusAtCylinder: 0 head: 0 sector: 1] == 1);
    CHECK ([[reloaded sectorAtCylinder: 0 head: 0 sector: 1]
        isEqual: [floppy sectorAtCylinder: 0 head: 0 sector: 1]]);
    [reloaded release];
    {
      NSString *scp = [directory stringByAppendingPathComponent: @"flux.scp"];
      NSData *flux = scp_from_dmk ([NSData dataWithContentsOfFile: dmk]);
      CHECK ([flux writeToFile: scp atomically: YES]);
      reloaded = [[DBFloppy alloc] initWithPath: scp readOnly: YES];
      CHECK ([reloaded statusAtCylinder: 0 head: 0 sector: 1] == 1);
      CHECK ([[reloaded sectorAtCylinder: 0 head: 0 sector: 1]
          isEqual: [floppy sectorAtCylinder: 0 head: 0 sector: 1]]);
      CHECK ([reloaded sectorsAtCylinder: 0 head: 0] == 9);
      [reloaded release];
      CHECK ([[flux subdataWithRange: NSMakeRange (0, 710)] writeToFile: scp
                                                            atomically: YES]);
      {
        BOOL rejected = NO;
        NS_DURING
        reloaded = [[DBFloppy alloc] initWithPath: scp readOnly: YES];
        [reloaded release];
        NS_HANDLER
        rejected = YES;
        NS_ENDHANDLER
        CHECK (rejected);
      }
    }
    [floppy release];
  }
  [machine release];
  {
    NSMutableData *delta = [NSMutableData dataWithLength: 534];
    NSMutableData *compressed =
        [NSMutableData dataWithLength: compressBound (534)];
    unsigned char *bytes = [delta mutableBytes];
    uLongf length = [compressed length];
    DBGuamDisk *diskImage;
    NSString *deltaPath = [path stringByAppendingString: @".zdelta"];
    bytes[0] = 0x65;
    bytes[1] = 0xca;
    bytes[3] = 1;
    bytes[8] = 0x80;
    bytes[10] = 0xbe;
    bytes[11] = 0xef;
    memset (bytes + 522, 255, 4);
    bytes[529] = 1;
    bytes[533] = 1;
    CHECK (compress2 ([compressed mutableBytes], &length, bytes, 534, 1)
           == Z_OK);
    [compressed setLength: length];
    CHECK ([compressed writeToFile: deltaPath atomically: YES]);
    diskImage = [[DBGuamDisk alloc] initWithPath: path];
    CHECK ([diskImage wordAtSector: 0 offset: 10] == 0xbeef);
    CHECK ([[NSData dataWithContentsOfFile: path] isEqual: raw]);
    [diskImage release];
  }
  [[NSFileManager defaultManager] removeItemAtPath: directory error: NULL];
  printf ("Passed %u feature checks\n", checks);
  [pool release];
  return 0;
}
