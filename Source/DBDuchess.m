/* Derived from Dwarf by Dr. Hans-Walter Latz. See COPYING. */
#import "DBDuchess.h"
#import "DBProcessorPrivate.h"
#include <string.h>
#include <time.h>
#include <zlib.h>

@implementation DBGuamDisk
- (void) loadImage: (NSString *)path
{
  NS_DURING
  NSData *data = [NSData dataWithContentsOfFile: path];
  const unsigned char *bytes = [data bytes];
  NSUInteger size = [data length];
  uint32_t sector;
  unsigned int word;
  if (size == 0 || size % 16384 || size > 512UL * 1024 * 1024)
    [NSException raise: @"DBDiskError"
                format: @"Invalid raw Pilot disk geometry"];
  _path = [[[path isAbsolutePath]
                ? path
                : [[[NSFileManager defaultManager] currentDirectoryPath]
                      stringByAppendingPathComponent: path]
      stringByStandardizingPath] stringByResolvingSymlinksInPath];
  [_path retain];
  _swapped = bytes[0] == 0x8a && bytes[1] == 0xa2;
  _heads = 2;
  _sectorCount = size / 512;
  _cylinders = _sectorCount / 32;
  _sectors = [[NSMutableData alloc] initWithLength: _sectorCount * 532UL];
  for (sector = 0; sector < _sectorCount; sector++)
    for (word = 0; word < 256; word++)
      {
        unsigned char *target = (unsigned char *) [_sectors mutableBytes]
                                + sector * 532UL + 20 + word * 2;
        target[0] = bytes[sector * 512UL + word * 2 + _swapped];
        target[1] = bytes[sector * 512UL + word * 2 + !_swapped];
      }
  {
    NSString *deltaPath = [path stringByAppendingString: @".zdelta"];
    if ([[NSFileManager defaultManager] fileExistsAtPath: deltaPath])
      {
        NSData *input = [NSData dataWithContentsOfFile: deltaPath];
        NSMutableData *delta = [NSMutableData dataWithLength: size * 2 + 65536];
        uLongf length = [delta length];
        const unsigned char *d;
        NSUInteger at = 4;
        unsigned int pageCount = 0, chunkCount = 0;
        if (input == nil
            || uncompress ([delta mutableBytes], &length, [input bytes],
                           [input length])
                   != Z_OK
            || length < 16)
          [NSException raise: @"DBDiskError" format: @"Invalid raw disk delta"];
        d = [delta bytes];
        if (d[0] != 0x65 || d[1] != 0xca || d[2] || d[3] != 1)
          [NSException raise: @"DBDiskError"
                      format: @"Invalid raw delta signature"];
        while (at + 4 <= length)
          {
            uint32_t chunk = ((uint32_t) d[at] << 24) | (d[at + 1] << 16)
                             | (d[at + 2] << 8) | d[at + 3];
            unsigned int mask, bit;
            at += 4;
            if (chunk == 0xffffffffU)
              break;
            if (at + 2 > length || (uint64_t) chunk * 16 >= _sectorCount)
              [NSException raise: @"DBDiskError" format: @"Invalid delta chunk"];
            mask = (d[at] << 8) | d[at + 1];
            at += 2;
            chunkCount++;
            for (bit = 0; bit < 16; bit++)
              if (mask & (0x8000 >> bit))
                {
                  if (at + 512 > length || chunk * 16 + bit >= _sectorCount)
                    [NSException raise: @"DBDiskError"
                                format: @"Truncated delta sector"];
                  memcpy ((unsigned char *) [_sectors mutableBytes]
                              + (chunk * 16 + bit) * 532UL + 20,
                          d + at, 512);
                  at += 512;
                  pageCount++;
                }
          }
        if (at + 8 != length
            || (((uint32_t) d[at] << 24) | (d[at + 1] << 16) | (d[at + 2] << 8)
                | d[at + 3])
                   != pageCount
            || (((uint32_t) d[at + 4] << 24) | (d[at + 5] << 16)
                | (d[at + 6] << 8) | d[at + 7])
                   != chunkCount)
          [NSException raise: @"DBDiskError" format: @"Invalid delta totals"];
      }
  }
  NS_HANDLER
  [self release];
  [localException raise];
  NS_ENDHANDLER
}
- (void) writeImageToPath: (NSString *)path
{
  if ([[NSFileManager defaultManager]
          fileExistsAtPath: [path stringByAppendingString: @".zdelta"]])
    [NSException raise: @"DBDiskError" format: @"Output has an existing delta"];
  NSMutableData *data = [NSMutableData dataWithLength: _sectorCount * 512UL];
  unsigned char *bytes = [data mutableBytes];
  uint32_t sector;
  unsigned int word;
  for (sector = 0; sector < _sectorCount; sector++)
    for (word = 0; word < 256; word++)
      {
        uint16_t value = [self wordAtSector: sector offset: word + 10];
        bytes[sector * 512UL + word * 2 + _swapped] = value >> 8;
        bytes[sector * 512UL + word * 2 + !_swapped] = value;
      }
  if (![data writeToFile: path atomically: YES])
    [NSException raise: @"DBDiskError" format: @"Cannot save raw disk %@", path];
}
@end

static void
db_guam_double (DBMemory *memory, uint32_t address, uint32_t value)
{
  [memory writeWord: address value: value];
  [memory writeWord: address + 1 value: value >> 16];
}

@implementation DBDuchess
- (id) initWithDisk: (NSString *)path
             width: (unsigned int)width
            height: (unsigned int)height
             color: (BOOL)color
       workingCopy: (BOOL)working
{
  DBMemory *memory;
  unsigned int i;
  uint32_t fcb = 0x8020;
  static const unsigned int sizes[16]
      = { 0, 16, 14, 15, 0, 7, 1, 7, 14, 0, 0, 0, 40, 0, 0, 0 };
  if (width < 16 || width > 2048 || width % 16 || height < 1 || height > 1536)
    {
      [self release];
      [NSException raise: NSInvalidArgumentException
                  format: @"Invalid display size"];
    }
  _displayWidth = width;
  _displayHeight = height;
  _displayStride = color ? ((width + 511) / 512) * 256 : width / 16;
  _displayPages = (_displayStride * height + 255) / 256;
  memory = [[DBMemory alloc] initWithRealPages: 8192 + _displayPages
                                  virtualPages: 65536];
  self = [super initWithMemory: memory post40: YES];
  [memory release];
  if (self == nil)
    return nil;
  NS_DURING
  _color = color;
  _displayDepth = color ? 8 : 1;
  _displayBase = 8192 * 256;
  _displayEnabled = YES;
  _hostID[0] = 0x1000;
  _hostID[1] = 0xfe31;
  _hostID[2] = 0xab21;
  _disk = working ? [[DBGuamDisk alloc] initWithWorkingCopyOfPath: path]
                  : [[DBGuamDisk alloc] initWithPath: path];
  for (i = 0; i < 65536; i++)
    [_memory mapPage: i
                  to: i < 128   ? i + 128
                     : i < 256 ? i - 128
                               : i
               flags: i < 8192 ? 0 : DB_MAP_VACANT];
  for (i = 0; i < 16; i++)
    {
      _agents[i] = sizes[i] ? fcb : 0;
      db_guam_double (_memory, 0x8000 + i * 2, _agents[i]);
      fcb += (sizes[i] + 1) & ~1U;
    }
  for (i = 0; i < 256; i++)
    _palette[i] = i ? 0xffffff : 0;
  fcb = _agents[1];
  [_memory writeWord: fcb + 4 value: 1];
  [_memory writeWord: fcb + 5 value: 1];
  [_memory writeWord: fcb + 6 value: 64];
  [_memory writeWord: fcb + 7 value: [_disk cylinders]];
  [_memory writeWord: fcb + 8 value: 2];
  [_memory writeWord: fcb + 9 value: 16];
  [_memory writeWord: _agents[2] + 5 value: 1];
  [_memory writeWord: _agents[2] + 6 value: 17];
  [_memory writeWord: _agents[3] + 14 value: 15];
  _receiveStopped = YES;
  for (i = 0; i < 3; i++)
    [_memory writeWord: _agents[3] + 10 + i value: _hostID[i]];
  fcb = _agents[8];
  for (i = 0; i < 3; i++)
    [_memory writeWord: fcb + i value: _hostID[i]];
  [_memory writeWord: fcb + 3 value: 1600];
  [_memory writeWord: fcb + 4 value: 40];
  db_guam_double (_memory, fcb + 6, 8192);
  db_guam_double (_memory, fcb + 8, 65536);
  [_memory writeWord: fcb + 13 value: 1];
  fcb = _agents[12];
  db_guam_double (_memory, fcb + 2, 8192);
  [_memory writeWord: fcb + 7 value: 1];
  [_memory writeWord: fcb + 37 value: color ? 2 : 0];
  [_memory writeWord: fcb + 38 value: width];
  [_memory writeWord: fcb + 39 value: height];
  [self releaseKeys];
  NS_HANDLER
  [self release];
  [localException raise];
  NS_ENDHANDLER
  return self;
}
- (void) bootWithGerm: (NSString *)path switches: (NSString *)switches
{
  NSData *data = [NSData dataWithContentsOfFile: path];
  unsigned int i, pages = [data length] / 512;
  if ([data length] % 512 || pages < 2 || pages > 96)
    [NSException raise: @"DBDeviceError"
                format: @"Invalid Duchess germ %@", path];
  for (i = 0; i < pages; i++)
    [_memory loadData: [data subdataWithRange: NSMakeRange (i * 512, 512)]
        atRealAddress: [_memory realPageForPage: i == 0 ? 512 : i] * 256];
  for (i = 0; i < 32; i++)
    [_memory writeWord: 0x3a0 + i value: 0];
  [_memory writeWord: 0x3a0 value: 1838];
  [_memory writeWord: 0x3a1 value: 2];
  [_memory writeWord: 0x3a2 value: 64];
  [_memory writeWord: 0x3ad value: 4012];
  if (switches == nil)
    switches = @"8Wy{|}\\346\\347\\350\\377";
  for (i = 0; i < [switches length]; i++)
    {
      unsigned int key = [switches characterAtIndex: i] & 255;
      uint32_t address;
      if (key == '\\' && i + 3 < [switches length])
        {
          unsigned int digit;
          key = 0;
          for (digit = 0; digit < 3; digit++)
            {
              unichar c = [switches characterAtIndex: ++i];
              if (c < '0' || c > '7')
                [NSException raise: NSInvalidArgumentException
                            format: @"Invalid boot switch"];
              key = (key << 3) | (c - '0');
            }
          key &= 255;
        }
      address = 0x3ae + key / 16;
      [_memory writeWord: address
                   value: [_memory readWord: address] | (0x8000 >> (key & 15))];
    }
  [self setGuestTraps: YES];
  [self transfer: [self readMDSDoubleWord: 0x202] source: 0 type: 1 free: NO];
}
- (void) setKey: (unsigned int)key pressed: (BOOL)pressed
{
  uint32_t address = _agents[5] + key / 16;
  uint16_t mask = 0x8000 >> (key & 15), value;
  if (key >= 112)
    return;
  value = [_memory readWord: address];
  [_memory writeWord: address value: pressed ? value & ~mask : value | mask];
}
- (void) releaseKeys
{
  unsigned int i;
  for (i = 0; i < 7; i++)
    [_memory writeWord: _agents[5] + i value: 65535];
}
- (void) setMouseX: (uint16_t)x y: (uint16_t)y
{
  [_memory writeWord: _agents[7] value: x];
  [_memory writeWord: _agents[7] + 1 value: y];
}
- (NSData *) displayRGB
{
  NSMutableData *data =
      [NSMutableData dataWithLength: _displayWidth * _displayHeight * 3];
  unsigned char *bytes = [data mutableBytes];
  unsigned int x, y;
  for (y = 0; y < _displayHeight; y++)
    for (x = 0; x < _displayWidth; x++)
      {
        uint16_t word = [_memory physicalWord: _displayBase + y * _displayStride
                                              + x / (_color ? 2 : 16)];
        unsigned int index = _color ? (word >> ((x & 1) ? 0 : 8)) & 255
                                    : (word >> (15 - (x & 15))) & 1;
        uint32_t rgb = _palette[index], offset = (y * _displayWidth + x) * 3;
        bytes[offset] = rgb >> 16;
        bytes[offset + 1] = rgb >> 8;
        bytes[offset + 2] = rgb;
      }
  return data;
}
- (void) runForInstructions: (uint32_t)count
{
  unsigned int i;
  [self pollDevices];
  for (i = 0; i < count && !_halted; i++)
    {
      if ((i & 255) == 0)
        [self pollDevices];
      [self pollProcesses];
      if (!_state.running)
        break;
      [self step];
    }
}
- (void) pollDevices
{
  [_network poll];
  while (!_receiveStopped && [_receiveIOCBs count])
    {
      NSData *packet = [_network receivePacket];
      uint32_t pointer, address;
      unsigned int length, actual, i, status = 2;
      const unsigned char *bytes;
      if (packet == nil)
        break;
      pointer = [[_receiveIOCBs objectAtIndex: 0] unsignedIntValue];
      [_receiveIOCBs removeObjectAtIndex: 0];
      address = [_memory readDoubleWord: pointer];
      length = [_memory readWord: pointer + 2];
      actual = MIN (length, [packet length]);
      bytes = [packet bytes];
      NS_DURING
      for (i = 0; i < (actual + 1) / 2; i++)
        [_memory validateWord: address + i writing: YES];
      for (i = 0; i < actual; i++)
        [_memory storeByte: address offset: i value: bytes[i]];
      if (actual < [packet length])
        status = 32;
      NS_HANDLER
      status = 8;
      actual = 0;
      NS_ENDHANDLER
      [_memory writeWord: pointer + 3 value: actual];
      [_memory writeWord: pointer + 4
                   value: ([_memory readWord: pointer + 4] & 0xff00) | status];
      _packetsReceived++;
      [self requestInterrupt: [_memory readWord: _agents[3] + 4]];
    }
}
- (BOOL) dispatch: (uint8_t)opcode escape: (BOOL)escape execute: (BOOL)execute
{
  if (escape && (opcode == 0x89 || opcode == 0x8a))
    {
      if (!execute)
        return YES;
      if (opcode == 0x89)
        [self callAgent: (uint16_t) [self pop]];
      else
        {
          unsigned int block = (uint16_t) [self pop];
          unsigned int total = (uint16_t) [self pop], i;
          uint32_t real = [self popLong], virtual = [self popLong];
          if (real != 8192 || total != _displayPages
              || (uint64_t) virtual + block < total
              || (uint64_t) virtual + block > [_memory virtualPages])
            [self hardwareError: [NSString
                                    stringWithFormat:
                                        @"Invalid MAPDISPLAY real=%u total=%u "
                                        @"block=%u virtual=%u expected=%u",
                                        real, total, block, virtual,
                                        _displayPages]];
          _displayVirtualStart = (virtual + block - total) * 256;
          _displayVirtualEnd = (virtual + block) * 256;
          for (i = 0; i < total; i++)
            [_memory mapPage: virtual + block - total + i to: real + i flags: 0];
        }
      return YES;
    }
  /* DBMachine's remaining extensions implement common stop instructions. */
  return [super dispatch: opcode escape: escape execute: execute];
}
- (void) callAgent: (unsigned int)index
{
  uint32_t fcb;
  unsigned int i;
  if (index >= 16 || _agents[index] == 0)
    [self hardwareError: @"Unavailable Guam agent"];
  fcb = _agents[index];
  if (index == 5)
    return;
  if (index == 6)
    {
      _beepSerial++;
      return;
    }
  if (index == 7)
    {
      if ([_memory readWord: fcb + 6] == 1)
        [self setMouseX: [_memory readWord: fcb + 4]
                      y: [_memory readWord: fcb + 5]];
      return;
    }
  if (index == 8)
    {
      uint32_t now = (uint32_t) time (NULL) + 2177452800U;
      uint16_t command = [_memory readWord: fcb + 12];
      if (command == 1)
        db_guam_double (_memory, fcb + 10, now + _gmtCorrection);
      if (command == 2)
        _gmtCorrection = [_memory readDoubleWord: fcb + 10] - now;
      [_memory writeWord: fcb + 13 value: command <= 2 ? 1 : 2];
      return;
    }
  if (index == 12)
    {
      unsigned int command = [_memory readWord: fcb];
      unsigned int color = [_memory readWord: fcb + 36], status = 0;
      if (command == 1 || command == 2)
        {
          if (color >= (_color ? 256U : 2U))
            status = 2;
          else if (command == 1)
            {
              uint16_t rg = [_memory readWord: fcb + 4];
              _palette[color] = ((rg & 255) << 16) | (rg & 0xff00)
                                | ([_memory readWord: fcb + 5] & 255);
            }
          else
            {
              uint32_t rgb = _palette[color];
              [_memory writeWord: fcb + 4
                           value: ((rgb >> 16) & 255) | (rgb & 0xff00)];
              [_memory writeWord: fcb + 5 value: rgb & 255];
            }
        }
      else if (command == 4)
        for (i = 0; i < 16; i++)
          _cursor[i] = [_memory readWord: fcb + 14 + i];
      else if (command == 6 || command == 7)
        {
          unsigned int x = [_memory readWord: fcb + 8],
                       y = [_memory readWord: fcb + 9];
          unsigned int width = [_memory readWord: fcb + 10],
                       height = [_memory readWord: fcb + 11];
          unsigned int sx = [_memory readWord: fcb + 12],
                       sy = [_memory readWord: fcb + 13];
          unsigned int mode = [_memory readWord: fcb + 34], row, column;
          NSMutableData *copy = [NSMutableData data];
          unsigned char *pixels;
          if (x + width > _displayWidth || y + height > _displayHeight)
            status = 4;
          else if (command == 6
                   && (sx + width > _displayWidth
                       || sy + height > _displayHeight))
            status = 5;
          else if (command == 7 && mode > 3)
            status = 1;
          if (status == 0)
            {
              [copy setLength: width * height];
              pixels = [copy mutableBytes];
              for (row = 0; row < height; row++)
                for (column = 0; column < width; column++)
                  {
                    unsigned int value;
                    if (command == 6)
                      {
                        uint16_t word = [_memory
                            physicalWord: _displayBase
                                         + (sy + row) * _displayStride
                                         + (sx + column) / (_color ? 2 : 16)];
                        value = (word >> (_color ? ((sx + column) & 1 ? 0 : 8)
                                                 : 15 - ((sx + column) & 15)))
                                & (_color ? 255 : 1);
                      }
                    else
                      {
                        uint16_t pattern =
                            [_memory readWord: fcb + 30 + ((y + row) & 3)];
                        unsigned int bit
                            = (pattern >> (15 - ((x + column) & 15))) & 1;
                        value = [_memory readWord: fcb + 6 + bit];
                      }
                    pixels[row * width + column] = value;
                  }
              for (row = 0; row < height; row++)
                for (column = 0; column < width; column++)
                  {
                    uint32_t address = _displayBase
                                       + (y + row) * _displayStride
                                       + (x + column) / (_color ? 2 : 16);
                    unsigned int shift = _color ? ((x + column) & 1 ? 0 : 8)
                                                : 15 - ((x + column) & 15);
                    unsigned int mask = _color ? 255 : 1,
                                 value = pixels[row * width + column];
                    uint16_t word = [_memory physicalWord: address];
                    unsigned int old = (word >> shift) & mask;
                    if (command == 7)
                      {
                        if (mode == 1)
                          value &= old;
                        else if (mode == 2)
                          value |= old;
                        else if (mode == 3)
                          value ^= old;
                      }
                    [_memory writePhysicalWord: address
                                         value: (word & ~(mask << shift))
                                               | ((value & mask) << shift)];
                  }
            }
        }
      else if (command > 7)
        status = 1;
      [_memory writeWord: fcb + 1 value: status];
      return;
    }
  if (index == 1)
    {
      [self serviceDisk];
      return;
    }
  if (index == 2)
    [self serviceFloppy];
  else if (index == 3)
    [self serviceNetwork: NO];
}
- (void) serviceDisk
{
  uint32_t fcb = _agents[1], pointer = [_memory readDoubleWord: fcb];
  unsigned int requests = 0;
  BOOL stop = [_memory readWord: fcb + 3] != 0;
  [_memory writeWord: fcb + 4 value: stop];
  if (stop)
    return;
  while (pointer)
    {
      unsigned int status = 1, word, count = [_memory readWord: pointer + 20];
      unsigned int command = [_memory readWord: pointer + 19];
      unsigned int coordinates = [_memory readWord: pointer + 15];
      uint32_t sector
          = ([_memory readWord: pointer + 14] * 2 + (coordinates >> 8)) * 16
            + (coordinates & 255);
      uint32_t buffer = [_memory readDoubleWord: pointer + 16];
      if (++requests > 65536)
        [self hardwareError: @"Cyclic Guam disk IOCB list"];
      if ([_memory readWord: pointer + 13] || (coordinates >> 8) >= 2
          || (coordinates & 255) >= 16 || command > 4)
        status = 15;
      while (count && status == 1)
        {
          if (sector >= [_disk sectorCount])
            {
              status = 8;
              break;
            }
          NS_DURING
          for (word = 0; word < 256 && command != 0 && command != 4; word++)
            [_memory validateWord: buffer + word writing: command == 1];
          for (word = 0; word < 256; word++)
            {
              if (command == 1)
                [_memory writeWord: buffer + word
                             value: [_disk wordAtSector: sector
                                                offset: word + 10]];
              else if (command == 2 || command == 4)
                [_disk writeSector: sector
                            offset: word + 10
                             value: command == 4
                                       ? 0
                                       : [_memory readWord: buffer + word]];
              else if (command == 3 &&
                       [_memory readWord: buffer + word] !=
                           [_disk wordAtSector: sector offset: word + 10])
                status = 10;
            }
          NS_HANDLER
          status = 13;
          NS_ENDHANDLER
          if (status != 1)
            break;
          _diskReads += command == 1;
          _diskWrites += command == 2 || command == 4;
          sector++;
          buffer += 256;
          [_memory writeWord: pointer + 20 value: --count];
          if ([_memory readWord: pointer + 18])
            db_guam_double (_memory, pointer + 16, buffer);
        }
      [_memory writeWord: pointer + 21 value: status];
      pointer = [_memory readDoubleWord: pointer + 22];
    }
  if (requests)
    [self requestInterrupt: [_memory readWord: fcb + 2]];
}
- (void) insertFloppy: (NSString *)path readOnly: (BOOL)readOnly
{
  DBFloppy *next;
  if ([_floppy changed])
    [NSException raise: @"DBFloppyError" format: @"Save changed media first"];
  next = [[DBFloppy alloc] initWithPath: path readOnly: readOnly];
  [_floppy release];
  _floppy = next;
  [_memory writeWord: _agents[2] + 7 value: [next cylinders]];
  [_memory writeWord: _agents[2] + 8 value: [next heads]];
  [_memory writeWord: _agents[2] + 9 value: [next sectorsAtCylinder: 0 head: 0]];
  [_memory writeWord: _agents[2] + 10 value: 1];
  [_memory writeWord: _agents[2] + 11 value: 1];
  [_memory writeWord: _agents[2] + 12 value: [next heads] > 1];
}
- (void) ejectFloppyDiscardingChanges: (BOOL)discard
{
  if (!discard && [_floppy changed])
    [NSException raise: @"DBFloppyError"
                format: @"Export changed floppy media before ejecting"];
  [_floppy release];
  _floppy = nil;
  [_memory writeWord: _agents[2] + 10 value: 0];
  [_memory writeWord: _agents[2] + 11 value: 1];
}
- (void) setHostID: (NSString *)identifier
{
  unsigned int i;
  [super setHostID: identifier];
  for (i = 0; i < 3; i++)
    {
      [_memory writeWord: _agents[8] + i value: _hostID[i]];
      [_memory writeWord: _agents[3] + 10 + i value: _hostID[i]];
    }
}
- (void) serviceNetwork: (BOOL)input
{
  uint32_t fcb = _agents[3], pointer;
  unsigned int requests = 0;
  BOOL stop = [_memory readWord: fcb + 6] != 0;
  (void) input;
  _receiveStopped = stop;
  [_memory writeWord: fcb + 7 value: stop];
  [_memory writeWord: fcb + 8 value: stop];
  if (_receiveIOCBs == nil)
    _receiveIOCBs = [[NSMutableArray alloc] init];
  if (stop)
    {
      [_receiveIOCBs removeAllObjects];
      [_network discardReceivedPackets];
      return;
    }
  pointer = [_memory readDoubleWord: fcb];
  while (pointer)
    {
      NSNumber *number = [NSNumber numberWithUnsignedInt: pointer];
      if (++requests > 64)
        [self hardwareError: @"Oversized or cyclic receive queue"];
      if (![_receiveIOCBs containsObject: number])
        [_receiveIOCBs addObject: number];
      pointer = [_memory readDoubleWord: pointer + 6];
    }
  db_guam_double (_memory, fcb, 0);
  pointer = [_memory readDoubleWord: fcb + 2];
  requests = 0;
  while (pointer)
    {
      unsigned int length = [_memory readWord: pointer + 2], i, status = 8;
      uint32_t address = [_memory readDoubleWord: pointer];
      if (++requests > 64)
        [self hardwareError: @"Oversized or cyclic transmit queue"];
      if (length >= 14 && length <= 766)
        {
          NSMutableData *packet = [NSMutableData dataWithLength: length];
          unsigned char *bytes = [packet mutableBytes];
          NS_DURING
          for (i = 0; i < length; i++)
            bytes[i] = [_memory fetchByte: address offset: i];
          status = [_network sendPacket: packet] ? 2 : 4;
          if (status == 2 && [_memory readWord: fcb + 9])
            [_network receiveLoopbackPacket: packet];
          NS_HANDLER
          status = 8;
          NS_ENDHANDLER
        }
      else
        status = 32;
      [_memory writeWord: pointer + 3 value: status == 2 ? length : 0];
      [_memory writeWord: pointer + 4
                   value: ([_memory readWord: pointer + 4] & 0xff00) | status];
      _packetsSent += status == 2;
      pointer = [_memory readDoubleWord: pointer + 6];
    }
  db_guam_double (_memory, fcb + 2, 0);
  if (requests)
    [self requestInterrupt: [_memory readWord: fcb + 5]];
}
- (void) serviceFloppy
{
  uint32_t fcb = _agents[2], pointer = [_memory readDoubleWord: fcb];
  unsigned int requests = 0;
  BOOL stop = [_memory readWord: fcb + 3] != 0;
  [_memory writeWord: fcb + 4 value: stop];
  if (stop)
    return;
  while (pointer)
    {
      unsigned int command = [_memory readWord: pointer + 1];
      unsigned int c = [_memory readWord: pointer + 2];
      unsigned int sh = [_memory readWord: pointer + 3], h = sh >> 8,
                   s = sh & 255;
      unsigned int count = [_memory readWord: pointer + 7], status = 1;
      unsigned int words = [_memory readWord: pointer + 9], i;
      uint32_t address = [_memory readDoubleWord: pointer + 4];
      BOOL increment = ([_memory readWord: pointer + 6] & 0x8000) != 0;
      if (++requests > 65536)
        [self hardwareError: @"Cyclic floppy queue"];
      if (_floppy == nil)
        status = 3;
      else if ([_memory readWord: pointer] != 0 || command > 5)
        status = 12;
      while (count && status == 1)
        {
          NSData *sector = [_floppy sectorAtCylinder: c head: h sector: s];
          NS_DURING
          if (command == 1)
            {
              status = [_floppy statusAtCylinder: c head: h sector: s];
              if (status == 1 && words * 2 == [sector length])
                {
                  const unsigned char *bytes = [sector bytes];
                  for (i = 0; i < words; i++)
                    [_memory validateWord: address + i writing: YES];
                  for (i = 0; i < words; i++)
                    [_memory writeWord: address + i
                                 value: (bytes[i * 2] << 8) | bytes[i * 2 + 1]];
                }
              else if (status == 1)
                status = 9;
            }
          else if (command == 2 || command == 3)
            {
              NSMutableData *data = [NSMutableData dataWithLength: words * 2];
              unsigned char *bytes = [data mutableBytes];
              for (i = 0; i < words * 2; i++)
                bytes[i] = [_memory fetchByte: address offset: i];
              status = [_floppy writeCylinder: c
                                         head: h
                                       sector: s
                                         data: data
                                      deleted: command == 3];
            }
          else if (command == 4)
            {
              [_memory writeWord: address value: c];
              [_memory writeWord: address + 1 value: (h << 8) | s];
            }
          else if (command == 5)
            {
              unsigned int sectors = [_memory readWord: pointer + 10], n = 0;
              NSMutableData *descriptors =
                  [NSMutableData dataWithLength: sectors * 4];
              unsigned char *bytes = [descriptors mutableBytes];
              while (n < 6 && (128U << n) < words * 2)
                n++;
              for (i = 0; i < sectors; i++)
                {
                  bytes[i * 4] = c;
                  bytes[i * 4 + 1] = h;
                  bytes[i * 4 + 2] = i + 1;
                  bytes[i * 4 + 3] = n;
                }
              status = [_floppy formatCylinder: c
                                          head: h
                                   descriptors: descriptors
                                          fill: 0];
            }
          NS_HANDLER
          status = 11;
          NS_ENDHANDLER
          if (status != 1)
            break;
          [_memory writeWord: pointer + 7 value: --count];
          if (increment)
            {
              address += words;
              db_guam_double (_memory, pointer + 4, address);
            }
          if (command == 5 || ++s > [_floppy sectorsAtCylinder: c head: h])
            {
              s = 1;
              if (++h >= [_floppy heads])
                {
                  h = 0;
                  c++;
                }
            }
          [_memory writeWord: pointer + 2 value: c];
          [_memory writeWord: pointer + 3 value: (h << 8) | s];
        }
      [_memory writeWord: pointer + 11 value: status];
      pointer = [_memory readDoubleWord: pointer + 12];
    }
  if (requests)
    [self requestInterrupt: [_memory readWord: fcb + 2]];
}
@end
