/* Derived from Dwarf by Dr. Hans-Walter Latz. See COPYING. */
#import "DBDisk.h"
#include <zlib.h>
#include <string.h>

static NSString *
db_absolute_path (NSString *path)
{
  if (![path isAbsolutePath])
    path = [[[NSFileManager defaultManager] currentDirectoryPath]
        stringByAppendingPathComponent: path];
  return [[path stringByStandardizingPath] stringByResolvingSymlinksInPath];
}

static uint16_t
db_be16 (const unsigned char *p)
{
  return ((uint16_t) p[0] << 8) | p[1];
}
static void
db_put16 (unsigned char *p, uint16_t value)
{
  p[0] = value >> 8;
  p[1] = value;
}
static NSData *
db_inflate (NSString *path)
{
  NSData *input = [NSData dataWithContentsOfFile: path];
  NSMutableData *output = [NSMutableData data];
  z_stream stream;
  unsigned char buffer[65536];
  int result;
  if (input == nil || [input length] > UINT_MAX)
    [NSException raise: @"DBDiskError" format: @"Cannot read disk %@", path];
  memset (&stream, 0, sizeof (stream));
  stream.next_in = (Bytef *) [input bytes];
  stream.avail_in = (uInt)[input length];
  if (inflateInit (&stream) != Z_OK)
    [NSException raise: @"DBDiskError"
                format: @"Cannot initialize decompressor"];
  do
    {
      stream.next_out = buffer;
      stream.avail_out = sizeof (buffer);
      result = inflate (&stream, Z_NO_FLUSH);
      [output appendBytes: buffer length: sizeof (buffer) - stream.avail_out];
      if ([output length] > 600000000)
        {
          result = Z_MEM_ERROR;
          break;
        }
    }
  while (result == Z_OK);
  inflateEnd (&stream);
  if (result != Z_STREAM_END)
    [NSException raise: @"DBDiskError"
                format: @"Invalid compressed disk %@", path];
  return output;
}

@interface DBDisk (Initialization)
- (void) loadImage: (NSString *)path;
- (void) writeImageToPath: (NSString *)path;
@end

@implementation DBDisk
+ (NSString *) workingDirectory
{
#ifdef GNUSTEP
  NSString *library = [NSHomeDirectory ()
      stringByAppendingPathComponent: @"GNUstep/Library"];
#else
  NSString *library = [NSHomeDirectory ()
      stringByAppendingPathComponent: @"Library/Application Support"];
#endif
  return [library stringByAppendingPathComponent: @"Daybreak/Hard Disks"];
}
- (id) initWithWorkingCopyOfPath: (NSString *)path
{
  NSString *root = db_absolute_path ([[self class] workingDirectory]);
  NSString *input = db_absolute_path (path);
  NSString *directory, *destination, *source;
  NSFileManager *manager = [NSFileManager defaultManager];
  self = [self initWithPath: input];
  if (self == nil)
    return nil;
  NS_DURING
  if ([input hasPrefix: [root stringByAppendingString: @"/"]])
    {
      source = [NSString stringWithContentsOfFile:
          [[input stringByDeletingLastPathComponent]
              stringByAppendingPathComponent: @"source.txt"]
          encoding: NSUTF8StringEncoding error: NULL];
      if (source == nil)
        [NSException raise: @"DBDiskError"
                    format: @"Managed disk has no source record: %@", input];
      _sourcePath = [source copy];
    }
  else
    {
      directory = [root stringByAppendingPathComponent:
          [[NSProcessInfo processInfo] globallyUniqueString]];
      if (![manager createDirectoryAtPath: directory
              withIntermediateDirectories: YES attributes: nil error: NULL])
        [NSException raise: @"DBDiskError"
                    format: @"Cannot create hard disk directory %@", directory];
      destination = [directory stringByAppendingPathComponent:
          [input lastPathComponent]];
      if (![input writeToFile: [directory stringByAppendingPathComponent:
                                  @"source.txt"]
                  atomically: YES encoding: NSUTF8StringEncoding error: NULL])
        [NSException raise: @"DBDiskError"
                    format: @"Cannot record disk source"];
      [self writeImageToPath: destination];
      _sourcePath = [_path copy];
      [_path release];
      _path = [destination copy];
    }
  _workingCopy = YES;
  NS_HANDLER
  [self release];
  [localException raise];
  NS_ENDHANDLER
  return self;
}
- (void) saveWorkingCopy
{
  if (_workingCopy && _changed)
    {
      [self writeImageToPath: _path];
      _changed = NO;
    }
}
- (id) initWithPath: (NSString *)path
{
  self = [super init];
  if (self != nil)
    {
      [self loadImage: path];
    }
  return self;
}
- (void) loadImage: (NSString *)path
{
  id volatile initializedSelf = self;
  NS_DURING
  unsigned int pass;
  _path = [db_absolute_path (path) copy];
  for (pass = 0; pass < 2; pass++)
    {
      NSString *inputPath
          = pass ? [path stringByAppendingString: @".zdelta"] : path;
      NSData *data;
      const unsigned char *bytes;
      NSUInteger size, position;
      uint32_t sectors, seenCount = 0;
      NSMutableData *seen;
      unsigned char *seenBytes, *destination;
      if (pass && ![[NSFileManager defaultManager] fileExistsAtPath: inputPath])
        break;
      data = db_inflate (inputPath);
      bytes = [data bytes];
      size = [data length];
      if (size < 12 || (size - 12) % 536 != 0)
        [NSException raise: @"DBDiskError"
                    format: @"Invalid disk record length"];
      sectors = ((uint32_t) db_be16 (bytes + 6) << 16) | db_be16 (bytes + 8);
      if (db_be16 (bytes) != 0xdaad || db_be16 (bytes + 10) != 0x5cc5
          || db_be16 (bytes + 2) == 0 || db_be16 (bytes + 2) > 16
          || db_be16 (bytes + 4) < 40 || sectors > 1048576
          || sectors
                 != (uint32_t) db_be16 (bytes + 2) * db_be16 (bytes + 4) * 16)
        [NSException raise: @"DBDiskError" format: @"Invalid disk geometry"];
      if (pass)
        {
          if (sectors != _sectorCount || db_be16 (bytes + 2) != _heads
              || db_be16 (bytes + 4) != _cylinders)
            [NSException raise: @"DBDiskError"
                        format: @"Delta geometry differs"];
        }
      else
        {
          _sectorCount = sectors;
          _heads = db_be16 (bytes + 2);
          _cylinders = db_be16 (bytes + 4);
          _sectors = [[NSMutableData alloc] initWithLength: sectors * 532UL];
        }
      destination = [_sectors mutableBytes];
      seen = [NSMutableData dataWithLength: sectors];
      seenBytes = [seen mutableBytes];
      for (position = 12; position < size; position += 536)
        {
          uint32_t index = ((uint32_t) db_be16 (bytes + position) << 16)
                           | db_be16 (bytes + position + 2);
          if (index >= sectors || seenBytes[index])
            [NSException raise: @"DBDiskError"
                        format: @"Invalid or duplicate disk sector"];
          seenBytes[index] = 1;
          seenCount++;
          memcpy (destination + index * 532UL, bytes + position + 4, 532);
        }
      if (!pass && seenCount != sectors)
        [NSException raise: @"DBDiskError" format: @"Incomplete base disk"];
    }
  NS_HANDLER
  [initializedSelf release];
  [localException raise];
  NS_ENDHANDLER
}
- (void) dealloc
{
  [_sectors release];
  [_path release];
  [_sourcePath release];
  [super dealloc];
}
- (NSString *) path
{
  return _path;
}
- (uint16_t) heads
{
  return _heads;
}
- (uint16_t) cylinders
{
  return _cylinders;
}
- (uint32_t) sectorCount
{
  return _sectorCount;
}
- (BOOL) changed
{
  return _changed;
}
- (uint16_t) wordAtSector: (uint32_t)sector offset: (unsigned int)offset
{
  if (sector >= _sectorCount || offset >= 266)
    [NSException raise: @"DBDiskError" format: @"Sector address out of range"];
  return db_be16 ((const unsigned char *) [_sectors bytes] + sector * 532UL
                  + offset * 2);
}
- (void) writeSector: (uint32_t)sector
             offset: (unsigned int)offset
              value: (uint16_t)value
{
  [self wordAtSector: sector offset: offset];
  db_put16 ((unsigned char *) [_sectors mutableBytes] + sector * 532UL
                + offset * 2,
            value);
  _changed = YES;
}
- (NSData *) germ
{
  uint32_t sector;
  unsigned int count;
  NSMutableData *data = [NSMutableData data];
  if ([self wordAtSector: 0 offset: 10] != 0xa28a)
    [NSException raise: @"DBDiskError"
                format: @"Invalid Pilot physical volume seal"];
  sector = [self wordAtSector: 0 offset: 10 + 0x21] * _heads * 16
           + ([self wordAtSector: 0 offset: 10 + 0x22] >> 8) * 16
           + ([self wordAtSector: 0 offset: 10 + 0x22] & 255);
  if (sector == 0)
    [NSException raise: @"DBDiskError" format: @"Disk has no germ"];
  for (count = 0; count < 96; count++, sector++)
    {
      [self wordAtSector: sector offset: 0];
      [data appendBytes: (const unsigned char *) [_sectors bytes]
                        + sector * 532UL + 20
                 length: 512];
      if ([self wordAtSector: sector offset: 8] == 65535 &&
          [self wordAtSector: sector offset: 9] == 65535)
        return data;
    }
  [NSException raise: @"DBDiskError" format: @"Unterminated or fragmented germ"];
  return nil;
}
- (void) saveCopyToPath: (NSString *)path
{
  if ([db_absolute_path (path) isEqual: _path]
      || [db_absolute_path (path) isEqual: _sourcePath])
    [NSException raise: @"DBDiskError" format: @"Choose a new output file"];
  [self writeImageToPath: path];
  if (!_workingCopy)
    _changed = NO;
}
- (void) writeImageToPath: (NSString *)path
{
  NSMutableData *raw, *compressed;
  unsigned char *bytes;
  uint32_t i;
  uLongf size;
  if ([[NSFileManager defaultManager]
          fileExistsAtPath: [path stringByAppendingString: @".zdelta"]])
    [NSException raise: @"DBDiskError"
                format: @"Output has an existing delta; choose a new filename"];
  raw = [NSMutableData dataWithLength: 12 + _sectorCount * 536UL];
  bytes = [raw mutableBytes];
  db_put16 (bytes, 0xdaad);
  db_put16 (bytes + 2, _heads);
  db_put16 (bytes + 4, _cylinders);
  db_put16 (bytes + 6, _sectorCount >> 16);
  db_put16 (bytes + 8, _sectorCount);
  db_put16 (bytes + 10, 0x5cc5);
  for (i = 0; i < _sectorCount; i++)
    {
      unsigned char *record = bytes + 12 + i * 536UL;
      db_put16 (record, i >> 16);
      db_put16 (record + 2, i);
      memcpy (record + 4, (const unsigned char *) [_sectors bytes] + i * 532UL,
              532);
    }
  size = compressBound ([raw length]);
  compressed = [NSMutableData dataWithLength: size];
  if (compress2 ([compressed mutableBytes], &size, [raw bytes], [raw length],
                 Z_DEFAULT_COMPRESSION)
      != Z_OK)
    [NSException raise: @"DBDiskError" format: @"Cannot compress disk"];
  [compressed setLength: size];
  if (![compressed writeToFile: path atomically: YES])
    [NSException raise: @"DBDiskError" format: @"Cannot save disk %@", path];
}
@end
