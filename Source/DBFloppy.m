/* IMD/DMK media decoding derived from Dwarf HFloppy. See COPYING. */
#import "DBFloppy.h"
#include <string.h>
static uint16_t
db_floppy_crc (uint16_t crc, unsigned char byte)
{
  unsigned int i;
  crc ^= (uint16_t) byte << 8;
  for (i = 0; i < 8; i++)
    {
      uint16_t polynomial = (crc & 0x8000) ? 0x1021 : 0;
      crc = (crc << 1) ^ polynomial;
    }
  return crc;
}
static NSNumber *
db_sector_key (unsigned int c, unsigned int h, unsigned int s)
{
  return [NSNumber numberWithUnsignedInt: (c << 16) | (h << 8) | s];
}
static void
db_floppy_error (void)
{
  [NSException raise: @"DBFloppyError"
              format: @"Invalid or truncated floppy image"];
}
static unsigned int
db_get_byte (const unsigned char *bytes, NSUInteger length, NSUInteger *offset)
{
  if (*offset >= length)
    db_floppy_error ();
  return bytes[(*offset)++];
}
static NSString *
db_floppy_path (NSString *path)
{
  if (![path isAbsolutePath])
    path = [[[NSFileManager defaultManager] currentDirectoryPath]
        stringByAppendingPathComponent: path];
  return [[path stringByStandardizingPath] stringByResolvingSymlinksInPath];
}
@interface DBFloppy (Private)
- (void) loadPath: (NSString *)path;
- (void) loadIMD: (NSData *)data;
- (void) loadDMK: (NSData *)data;
- (void) loadRaw: (NSData *)data;
- (void) loadSCP: (NSData *)data;
- (void) exportRaw: (NSString *)path dmk: (BOOL)dmk;
- (void) addCylinder: (unsigned int)c
               head: (unsigned int)h
             sector: (unsigned int)s
               data: (NSData *)data
               kind: (unsigned int)kind
               mode: (unsigned int)mode;
@end
@implementation DBFloppy
- (id) initWithPath: (NSString *)path readOnly: (BOOL)readOnly
{
  self = [super init];
  if (self != nil)
    {
      _readOnly = readOnly;
      [self loadPath: path];
    }
  return self;
}
- (void) loadPath: (NSString *)path
{
  id volatile initializedSelf = self;
  NS_DURING
  NSData *data = [NSData dataWithContentsOfFile: path];
  _path = [db_floppy_path (path) copy];
  _sectors = [NSMutableDictionary new];
  _kinds = [NSMutableDictionary new];
  _modes = [NSMutableDictionary new];
  if (data == nil || [data length] > 128 * 1024 * 1024)
    db_floppy_error ();
  if ([[[path pathExtension] lowercaseString] isEqual: @"imd"])
    [self loadIMD: data];
  else if ([[[path pathExtension] lowercaseString] isEqual: @"scp"])
    [self loadSCP: data];
  else if ([[[path pathExtension] lowercaseString] isEqual: @"dmk"])
    {
      [self loadDMK: data];
    }
  else if ([[NSArray arrayWithObjects: @"img", @"raw", nil]
               containsObject: [[path pathExtension] lowercaseString]])
    [self loadRaw: data];
  else
    [NSException raise: @"DBFloppyError"
                format: @"Expected .imd, .dmk, .img or .raw media"];
  if ([_sectors count] == 0)
    db_floppy_error ();
  NS_HANDLER
  [initializedSelf release];
  [localException raise];
  NS_ENDHANDLER
}
- (void) dealloc
{
  [_path release];
  [_sectors release];
  [_kinds release];
  [_modes release];
  [super dealloc];
}
- (NSString *) path
{
  return _path;
}
- (unsigned int) cylinders
{
  return _cylinders;
}
- (unsigned int) heads
{
  return _heads;
}
- (BOOL) readOnly
{
  return _readOnly;
}
- (BOOL) changed
{
  return _changed;
}
- (void) addCylinder: (unsigned int)c
               head: (unsigned int)h
             sector: (unsigned int)s
               data: (NSData *)data
               kind: (unsigned int)kind
               mode: (unsigned int)mode
{
  NSNumber *key = db_sector_key (c, h, s);
  if (c >= 85 || h > 1 || s == 0 || s > 255 ||
      [_sectors objectForKey: key] != nil)
    db_floppy_error ();
  [_sectors setObject: [NSData dataWithData: data] forKey: key];
  [_kinds setObject: [NSNumber numberWithUnsignedInt: kind] forKey: key];
  [_modes setObject: [NSNumber numberWithUnsignedInt: mode]
             forKey: db_sector_key (c, h, 0)];
  _cylinders = MAX (_cylinders, c + 1);
  _heads = MAX (_heads, h + 1);
}
- (void) loadIMD: (NSData *)data
{
  const unsigned char *bytes = [data bytes];
  NSUInteger length = [data length], at = 0;
  if (length < 4 || memcmp (bytes, "IMD ", 4))
    db_floppy_error ();
  while (db_get_byte (bytes, length, &at) != 0x1a)
    {
    }
  while (at < length)
    {
      unsigned int mode = db_get_byte (bytes, length, &at),
                   c = db_get_byte (bytes, length, &at);
      unsigned int h = db_get_byte (bytes, length, &at),
                   n = db_get_byte (bytes, length, &at);
      unsigned int code = db_get_byte (bytes, length, &at), ids[255], cs[255],
                   hs[255], i;
      if (mode > 5 || c >= 85 || (h & 0x3f) > 1 || n == 0 || code > 6)
        db_floppy_error ();
      for (i = 0; i < n; i++)
        {
          ids[i] = db_get_byte (bytes, length, &at);
          cs[i] = c;
          hs[i] = h & 1;
        }
      if (h & 0x80)
        for (i = 0; i < n; i++)
          cs[i] = db_get_byte (bytes, length, &at);
      if (h & 0x40)
        for (i = 0; i < n; i++)
          hs[i] = db_get_byte (bytes, length, &at);
      for (i = 0; i < n; i++)
        {
          unsigned int kind = db_get_byte (bytes, length, &at),
                       size = 128U << code;
          NSMutableData *sector = [NSMutableData dataWithLength: size];
          if (kind > 8)
            db_floppy_error ();
          if (kind != 0 && (kind & 1))
            {
              if (length - at < size)
                db_floppy_error ();
              memcpy ([sector mutableBytes], bytes + at, size);
              at += size;
            }
          else if (kind != 0)
            memset ([sector mutableBytes], db_get_byte (bytes, length, &at),
                    size);
          /* Normalize compressed type numbers to their uncompressed form. */
          [self addCylinder: cs[i]
                       head: hs[i]
                     sector: ids[i]
                       data: sector
                       kind: kind ? (kind - 1) / 2 * 2 + 1 : 0
                       mode: mode];
        }
    }
}
- (void) loadRaw: (NSData *)data
{
  static const unsigned int geometries[][3]
      = { { 40, 1, 8 }, { 40, 1, 9 },  { 40, 2, 8 },  { 40, 2, 9 },
          { 80, 2, 9 }, { 80, 2, 15 }, { 80, 2, 18 }, { 80, 2, 36 } };
  unsigned int i, c, h, sector;
  NSUInteger offset = 0;
  for (i = 0; i < sizeof (geometries) / sizeof (geometries[0]); i++)
    if ([data length]
        == geometries[i][0] * geometries[i][1] * geometries[i][2] * 512)
      break;
  if (i == sizeof (geometries) / sizeof (geometries[0]))
    [NSException raise: @"DBFloppyError"
                format: @"Unrecognized raw floppy geometry"];
  for (c = 0; c < geometries[i][0]; c++)
    for (h = 0; h < geometries[i][1]; h++)
      for (sector = 1; sector <= geometries[i][2]; sector++, offset += 512)
        [self addCylinder: c
                     head: h
                   sector: sector
                     data: [data subdataWithRange: NSMakeRange (offset, 512)]
                     kind: 1
                     mode: 5];
}
- (void) loadDMK: (NSData *)data
{
  const unsigned char *bytes = [data bytes];
  NSUInteger length = [data length];
  unsigned int tracks, size, heads, c, h, i;
  if (length < 16)
    db_floppy_error ();
  _readOnly |= bytes[0] == 255;
  tracks = bytes[1];
  size = bytes[2] | (bytes[3] << 8);
  heads = (bytes[4] & 0x10) ? 1 : 2;
  if (!tracks || tracks > 85 || size < 128 || size > 16384
      || length != 16U + tracks * heads * size || bytes[12] || bytes[13]
      || bytes[14] || bytes[15])
    db_floppy_error ();
  for (c = 0; c < tracks; c++)
    for (h = 0; h < heads; h++)
      {
        const unsigned char *track = bytes + 16 + (c * heads + h) * size;
        for (i = 0; i < 64; i++)
          {
            unsigned int entry = track[i * 2] | (track[i * 2 + 1] << 8),
                         at = entry & 0x3fff;
            unsigned int stride
                = (!(entry & 0x8000) && !(bytes[4] & 0x40)) ? 2 : 1;
            unsigned int sc, sh, id, code, j, mark = 0, limit, count;
            BOOL badCRC = NO;
            uint16_t crc;
            unsigned int crcAt;
            NSMutableData *sector;
            unsigned char *out;
            if (!at)
              continue;
            if (at < 128 || at + 7 * stride > size || track[at] != 0xfe)
              db_floppy_error ();
            sc = track[at + stride];
            sh = track[at + 2 * stride];
            id = track[at + 3 * stride];
            code = track[at + 4 * stride];
            if (code > 6)
              db_floppy_error ();
            crc = (entry & 0x8000) ? 0xcdb4 : 0xffff;
            for (crcAt = 0; crcAt < 7; crcAt++)
              crc = db_floppy_crc (crc, track[at + crcAt * stride]);
            badCRC = crc != 0;
            at += 7 * stride;
            limit = MIN (size, at + 50 * stride);
            while (at < limit)
              {
                mark = track[at];
                at += stride;
                if (mark >= 0xf8 && mark <= 0xfb)
                  break;
              }
            if (mark < 0xf8 || mark > 0xfb)
              db_floppy_error ();
            count = 128U << code;
            if ((count + 2) * stride > size - at)
              db_floppy_error ();
            sector = [NSMutableData dataWithLength: count];
            out = [sector mutableBytes];
            for (j = 0; j < count; j++)
              out[j] = track[at + j * stride];
            crc = (entry & 0x8000) ? 0xcdb4 : 0xffff;
            crc = db_floppy_crc (crc, mark);
            for (crcAt = 0; crcAt < count + 2; crcAt++)
              crc = db_floppy_crc (crc, track[at + crcAt * stride]);
            badCRC |= crc != 0;
            [self addCylinder: sc
                         head: sh
                       sector: id
                         data: sector
                         kind: (badCRC ? 4 : 0)
                              + ((mark == 0xf8 || mark == 0xf9) ? 3 : 1)
                         mode: (entry & 0x8000) ? 5 : 2];
          }
      }
}
- (NSArray *) sectorIDsAtCylinder: (unsigned int)c head: (unsigned int)h
{
  NSMutableArray *ids = [NSMutableArray array];
  unsigned int i;
  for (i = 1; i <= 255; i++)
    if ([_sectors objectForKey: db_sector_key (c, h, i)] != nil)
      [ids addObject: [NSNumber numberWithUnsignedInt: i]];
  return ids;
}
- (unsigned int) sectorsAtCylinder: (unsigned int)c head: (unsigned int)h
{
  return (unsigned int) [[self sectorIDsAtCylinder: c head: h] count];
}
- (NSData *) sectorAtCylinder: (unsigned int)c
                        head: (unsigned int)h
                      sector: (unsigned int)s
{
  if (c >= _cylinders || h >= _heads || s == 0 || s > 255)
    return nil;
  return [_sectors objectForKey: db_sector_key (c, h, s)];
}
- (unsigned int) statusAtCylinder: (unsigned int)c
                            head: (unsigned int)h
                          sector: (unsigned int)s
{
  unsigned int kind;
  if ([self sectorAtCylinder: c head: h sector: s] == nil)
    return 6;
  kind = [[_kinds objectForKey: db_sector_key (c, h, s)] unsignedIntValue];
  return kind == 0 ? 6 : kind >= 5 ? 8 : kind == 3 ? 5 : 1;
}
- (unsigned int) writeCylinder: (unsigned int)c
                         head: (unsigned int)h
                       sector: (unsigned int)s
                         data: (NSData *)data
                      deleted: (BOOL)deleted
{
  NSData *old = [self sectorAtCylinder: c head: h sector: s];
  NSNumber *key = db_sector_key (c, h, s);
  if (_readOnly)
    return 10;
  if (old == nil)
    return 6;
  if ([old length] != [data length])
    return 9;
  [_sectors setObject: [NSData dataWithData: data] forKey: key];
  [_kinds setObject: [NSNumber numberWithInt: deleted ? 3 : 1] forKey: key];
  _changed = YES;
  return 1;
}
- (unsigned int) formatCylinder: (unsigned int)c
                          head: (unsigned int)h
                   descriptors: (NSData *)descriptors
                          fill: (unsigned char)fill
{
  const unsigned char *bytes = [descriptors bytes];
  NSUInteger n = [descriptors length], i;
  NSMutableSet *seen = [NSMutableSet set];
  NSArray *old;
  if (_readOnly)
    return 10;
  if (c >= _cylinders || h >= _heads || n == 0 || n % 4 || n > 255 * 4)
    return 12;
  for (i = 0; i < n; i += 4)
    {
      NSNumber *id = [NSNumber numberWithUnsignedInt: bytes[i + 2]];
      if (bytes[i] != c || bytes[i + 1] != h || bytes[i + 2] == 0
          || bytes[i + 3] > 6 || [seen containsObject: id])
        return 12;
      [seen addObject: id];
    }
  old = [self sectorIDsAtCylinder: c head: h];
  for (i = 0; i < [old count]; i++)
    {
      NSNumber *key
          = db_sector_key (c, h, [[old objectAtIndex: i] unsignedIntValue]);
      [_sectors removeObjectForKey: key];
      [_kinds removeObjectForKey: key];
    }
  for (i = 0; i < n; i += 4)
    {
      NSMutableData *sector =
          [NSMutableData dataWithLength: 128U << bytes[i + 3]];
      memset ([sector mutableBytes], fill, [sector length]);
      [self addCylinder: c
                   head: h
                 sector: bytes[i + 2]
                   data: sector
                   kind: 1
                   mode: 5];
    }
  _changed = YES;
  return 1;
}
- (void) saveCopyToPath: (NSString *)path
{
  if ([[[path pathExtension] lowercaseString] isEqual: @"dmk"])
    {
      [self exportRaw: path dmk: YES];
      return;
    }
  if ([[[path pathExtension] lowercaseString] isEqual: @"img"] ||
      [[[path pathExtension] lowercaseString] isEqual: @"raw"])
    {
      [self exportRaw: path dmk: NO];
      return;
    }
  NSMutableData *output =
      [NSMutableData dataWithBytes: "IMD Daybreak floppy copy\r\n\x1a"
                            length: 27];
  unsigned int c, h;
  if ([db_floppy_path (path) isEqual: _path]
      || ![[[path pathExtension] lowercaseString] isEqual: @"imd"])
    [NSException raise: @"DBFloppyError"
                format: @"Export to a separate .imd file"];
  for (c = 0; c < _cylinders; c++)
    for (h = 0; h < _heads; h++)
      {
        /* Group sectors by size: IMD allows repeated physical track records.
         */
        unsigned int code;
        for (code = 0; code <= 6; code++)
          {
            NSArray *ids = [self sectorIDsAtCylinder: c head: h];
            NSMutableData *map = [NSMutableData data];
            NSUInteger i;
            unsigned char header[5];
            for (i = 0; i < [ids count]; i++)
              {
                unsigned int id = [[ids objectAtIndex: i] unsignedIntValue];
                if ([[self sectorAtCylinder: c head: h sector: id] length]
                    == (128U << code))
                  {
                    unsigned char b = id;
                    [map appendBytes: &b length: 1];
                  }
              }
            if ([map length] == 0)
              continue;
            header[0] = [[_modes objectForKey: db_sector_key (c, h, 0)]
                unsignedIntValue];
            header[1] = c;
            header[2] = h;
            header[3] = [map length];
            header[4] = code;
            [output appendBytes: header length: 5];
            [output appendData: map];
            for (i = 0; i < [map length]; i++)
              {
                unsigned int id = ((const unsigned char *) [map bytes])[i];
                unsigned char kind = [[_kinds
                    objectForKey: db_sector_key (c, h, id)] unsignedIntValue];
                [output appendBytes: &kind length: 1];
                if (kind)
                  [output appendData: [self sectorAtCylinder: c
                                                       head: h
                                                     sector: id]];
              }
          }
      }
  if (![output writeToFile: path atomically: YES])
    [NSException raise: @"DBFloppyError"
                format: @"Cannot export floppy %@", path];
  _changed = NO;
}
- (void) exportRaw: (NSString *)path dmk: (BOOL)dmk
{
  NSMutableData *output;
  unsigned int c, h, trackSize = 128,
                     sectors = [self sectorsAtCylinder: 0 head: 0];
  if ([db_floppy_path (path) isEqual: _path])
    [NSException raise: @"DBFloppyError"
                format: @"Choose a separate output file"];
  if (dmk)
    {
      for (c = 0; c < _cylinders; c++)
        for (h = 0; h < _heads; h++)
          {
            NSArray *ids = [self sectorIDsAtCylinder: c head: h];
            unsigned int i, needed = 128;
            if ([ids count] > 64)
              db_floppy_error ();
            for (i = 0; i < [ids count]; i++)
              needed += 64 +
                        [[self sectorAtCylinder: c
                                           head: h
                                         sector: [[ids objectAtIndex: i]
                                                    unsignedIntValue]] length];
            trackSize = MAX (trackSize, needed);
          }
      if (trackSize > 16384)
        db_floppy_error ();
      output =
          [NSMutableData dataWithLength: 16 + _cylinders * _heads * trackSize];
      {
        unsigned char *header = [output mutableBytes];
        header[0] = _readOnly ? 255 : 0;
        header[1] = _cylinders;
        header[2] = trackSize;
        header[3] = trackSize >> 8;
        header[4] = _heads == 1 ? 0x10 : 0;
      }
    }
  else
    output = [NSMutableData data];
  for (c = 0; c < _cylinders; c++)
    for (h = 0; h < _heads; h++)
      {
        NSArray *ids = [self sectorIDsAtCylinder: c head: h];
        unsigned int i, at = 128;
        unsigned char *track = dmk ? (unsigned char *) [output mutableBytes]
                                         + 16 + (c * _heads + h) * trackSize
                                   : NULL;
        if (!dmk && [ids count] != sectors)
          db_floppy_error ();
        for (i = 0; i < [ids count]; i++)
          {
            unsigned int id = [[ids objectAtIndex: i] unsignedIntValue];
            NSData *sector = [self sectorAtCylinder: c head: h sector: id];
            unsigned int status = [self statusAtCylinder: c head: h sector: id];
            if (dmk)
              {
                unsigned int n = 0, start, j;
                uint16_t crc;
                while ((128U << n) < [sector length])
                  n++;
                at += 12;
                track[at++] = 0xa1;
                track[at++] = 0xa1;
                track[at++] = 0xa1;
                track[i * 2] = at;
                track[i * 2 + 1] = (at >> 8) | 0x80;
                start = at;
                track[at++] = 0xfe;
                track[at++] = c;
                track[at++] = h;
                track[at++] = id;
                track[at++] = n;
                crc = 0xcdb4;
                for (j = start; j < at; j++)
                  crc = db_floppy_crc (crc, track[j]);
                track[at++] = crc >> 8;
                track[at++] = crc;
                at += 12;
                track[at++] = 0xa1;
                track[at++] = 0xa1;
                track[at++] = 0xa1;
                start = at;
                track[at++] = status == 5 ? 0xf8 : 0xfb;
                memcpy (track + at, [sector bytes], [sector length]);
                at += [sector length];
                crc = 0xcdb4;
                for (j = start; j < at; j++)
                  crc = db_floppy_crc (crc, track[j]);
                if (status == 8 || status == 6)
                  crc ^= 1;
                track[at++] = crc >> 8;
                track[at++] = crc;
              }
            else
              {
                if (id != i + 1 || [sector length] != 512 || status != 1)
                  [NSException raise: @"DBFloppyError"
                              format: @"Raw export requires contiguous, good "
                                     @"512-byte sectors"];
                [output appendData: sector];
              }
          }
      }
  if (![output writeToFile: path atomically: YES])
    [NSException raise: @"DBFloppyError" format: @"Cannot export %@", path];
  _changed = NO;
}
@end
