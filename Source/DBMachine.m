/* Derived from Dwarf by Dr. Hans-Walter Latz. See COPYING. */
#import "DBMachine.h"
#import "DBProcessorPrivate.h"
#include <time.h>
#include "DBIOInitial.inc"

static uint16_t
db_swap (uint16_t value)
{
  return (value << 8) | (value >> 8);
}

@interface DBMachine (Initialization)
- (void) configureDisk: (NSString *)path switches: (NSString *)switches;
@end

@implementation DBMachine
- (id) initWithDisk: (NSString *)path switches: (NSString *)switches
{
  DBMemory *memory = [[DBMemory alloc] initWithRealPages: 8192
                                            virtualPages: 65536];
  self = [super initWithMemory: memory post40: NO];
  [memory release];
  if (self != nil)
    {
      [self configureDisk: path switches: switches];
    }
  return self;
}
- (void) configureDisk: (NSString *)path switches: (NSString *)switches
{
  id volatile initializedSelf = self;
  NS_DURING
  NSData *germ;
  const unsigned char *bytes;
  unsigned int i, page, pages, target;
  _hostID[0] = 0x1000;
  _hostID[1] = 0xfe31;
  _hostID[2] = 0xab21;
  _receiveStopped = YES;
  _disk = [[DBDisk alloc] initWithPath: path];
  germ = [_disk germ];
  bytes = [germ bytes];
  pages = (unsigned int) [germ length] / 512;
  _post40 = bytes[0] == 0 && bytes[1] == 0 && bytes[2] == 0 && bytes[3] == 0;
  for (i = 3; i < 16; i += 2)
    if (bytes[i * 2] != 0 || bytes[i * 2 + 1] != 0)
      _post40 = NO;
  for (page = 0; page < 65536; page++)
    {
      uint32_t real = page < 192   ? page + 96
                      : page < 256 ? page - 160
                                   : page + 32;
      [_memory mapPage: page
                    to: real < 7680 ? real : 0
                 flags: real < 7680 ? 0 : DB_MAP_VACANT];
    }
  for (i = 0; i < sizeof (db_io_initial) / sizeof (db_io_initial[0]); i++)
    [_memory writePhysicalWord: db_io_initial[i][0] value: db_io_initial[i][1]];
  [_memory writePhysicalWord: 0x224c value: 0x4130];
  [_memory writePhysicalWord: 0x224d value: 64];
  [_memory writePhysicalWord: 0x224e value: 0x1000 | [_disk heads]];
  for (i = 0x224f; i <= 0x2251; i++)
    [_memory writePhysicalWord: i value: db_swap ([_disk cylinders])];
  for (page = 0; page < pages; page++)
    {
      target = _post40 ? (page == 0 ? 512 : page) : page + 1;
      [_memory loadData: [germ subdataWithRange: NSMakeRange (page * 512, 512)]
          atRealAddress: [_memory realPageForPage: target] * 256];
    }
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
      if (key == '\\' && i + 3 < [switches length])
        {
          unsigned int j;
          key = 0;
          for (j = 0; j < 3; j++)
            {
              unichar c = [switches characterAtIndex: ++i];
              if (c < '0' || c > '7')
                [NSException raise: NSInvalidArgumentException
                            format: @"Invalid octal boot switch"];
              key = (key << 3) | (c - '0');
            }
          key &= 255;
        }
      target = 0x3ae + key / 16;
      [_memory writeWord: target
                   value: [_memory readWord: target] | (0x8000 >> (key & 15))];
    }
  [self setGuestTraps: YES];
  [self transfer: [self readMDSDoubleWord: 0x202] source: 0 type: 1 free: NO];
  NS_HANDLER
  [initializedSelf release];
  [localException raise];
  NS_ENDHANDLER
}
- (void) dealloc
{
  [_disk release];
  [_floppy release];
  [_pendingFloppy release];
  [_network release];
  [_receiveIOCBs release];
  [super dealloc];
}
- (DBDisk *) disk
{
  return _disk;
}
- (uint64_t) diskReads
{
  return _diskReads;
}
- (uint64_t) diskWrites
{
  return _diskWrites;
}
- (BOOL) halted
{
  return _halted;
}
- (BOOL) displayEnabled
{
  return _displayEnabled;
}
- (NSData *) displayData
{
  NSMutableData *data = [NSMutableData dataWithLength: 104 * 633];
  unsigned char *bytes = [data mutableBytes];
  unsigned int i;
  for (i = 0; i < 52 * 633; i++)
    {
      uint16_t word = [_memory physicalWord: 7936 * 256 + i];
      bytes[i * 2] = word >> 8;
      bytes[i * 2 + 1] = word;
    }
  return data;
}
- (void) setKey: (unsigned int)key pressed: (BOOL)pressed
{
  uint16_t value, mask;
  uint32_t address;
  if (key >= 144)
    [NSException raise: NSInvalidArgumentException
                format: @"Invalid Level V key"];
  address = 0x212a + key / 16;
  mask = 0x8000 >> (key & 15);
  value = [_memory physicalWord: address];
  [_memory writePhysicalWord: address
                       value: pressed ? value & ~mask : value | mask];
}
- (void) releaseKeys
{
  unsigned int i;
  for (i = 0; i < 9; i++)
    [_memory writePhysicalWord: 0x212a + i value: 65535];
}
- (void) setMouseX: (uint16_t)x y: (uint16_t)y
{
  [_memory writePhysicalWord: 0x2128 value: x];
  [_memory writePhysicalWord: 0x2129 value: y];
}
- (void) runForInstructions: (uint32_t)count
{
  unsigned int i;
  [self pollDevices];
  for (i = 0; i < count && !_halted; i++)
    {
      uint32_t now = [self intervalTimer];
      if ((i & 255) == 0 && (uint32_t) (now - _lastDevicePoll) >= 625)
        {
          _lastDevicePoll = now;
          [self pollDevices];
        }
      if (_displayEnabled && (uint32_t) (now - _lastRetrace) >= 1563)
        {
          _lastRetrace = now;
          [self requestInterrupt: [_memory physicalWord: 0x21c5]];
        }
      [self pollProcesses];
      if (!_state.running)
        break;
      [self step];
    }
}
- (void) notifyDevice: (uint16_t)mask
{
  if (mask == 0 || mask == [_memory physicalWord: 0x21f5])
    {
      uint16_t command = [_memory physicalWord: 0x21f6] & 255;
      uint16_t a = 0, b = 0, c = 0;
      uint32_t gmt = (uint32_t) time (NULL) + 731U * 86400 + 2114294400U
                     + _gmtCorrection;
      switch (command)
        {
        case 0:
          return;
        case 1:
          a = gmt;
          b = gmt >> 16;
          break;
        case 2:
          _gmtCorrection
              += (uint32_t) db_swap ([_memory physicalWord: 0x21f7])
                 + ((uint32_t) db_swap ([_memory physicalWord: 0x21f8]) << 16)
                 - gmt;
          break;
        case 3:
          a = db_swap (_hostID[0]);
          b = db_swap (_hostID[1]);
          c = db_swap (_hostID[2]);
          break;
        case 4:
          a = 7680;
          b = 256;
          break;
        case 5:
          a = 32;
          b = 7679;
          c = 7648;
          break;
        case 6:
          a = 1;
          b = 7936;
          c = 256;
          break;
        case 7:
          a = 2;
          break;
        case 8:
          break;
        case 9:
          _halted = YES;
          break;
        case 10:
          a = 1;
          break;
        case 11:
          a = 3;
          break;
        default:
          [NSException raise: @"DBDeviceError"
                      format: @"Unknown processor command %u", command];
        }
      if (command != 2)
        {
          [_memory writePhysicalWord: 0x21f7 value: db_swap (a)];
          [_memory writePhysicalWord: 0x21f8 value: db_swap (b)];
          [_memory writePhysicalWord: 0x21f9 value: db_swap (c)];
        }
      [_memory writePhysicalWord: 0x21f6 value: 0x100];
      return;
    }
  if (mask == [_memory physicalWord: 0x2225])
    {
      [self serviceDisk];
      return;
    }
  if (mask == [_memory physicalWord: 0x22fe]
      || mask == [_memory physicalWord: 0x22fd])
    {
      [self serviceNetwork: mask == [_memory physicalWord: 0x22fe]];
      return;
    }
  if (mask == [_memory physicalWord: 0x228a])
    {
      [self serviceFloppy];
      return;
    }
  if (mask == [_memory physicalWord: 0x2112])
    return;
  [NSException raise: @"DBDeviceError"
              format: @"Unimplemented IOP notification %04x", mask];
}
- (void) serviceDisk
{
  uint16_t pointer;
  unsigned int requests = 0;
  if ([_memory physicalWord: 0x2227] != 0)
    {
      [_memory writePhysicalWord: 0x222b value: 0xffff];
      return;
    }
  [_memory writePhysicalWord: 0x222b value: 0];
  if ([_memory physicalWord: 0x222d] != 0)
    {
      [_memory writePhysicalWord: 0x2229 value: 0];
      [_memory writePhysicalWord: 0x222d value: 0];
    }
  pointer = db_swap ([_memory physicalWord: 0x2238]);
  while (pointer != 0)
    {
      uint32_t dob = pointer + 46, buffer, sector, lastSector, labelPage;
      uint16_t count, operation, flags, cylinder, coordinates, negative;
      unsigned int i, error = 0;
      uint16_t completed = 0;
      BOOL increment;
      if (++requests > 65536)
        [self hardwareError: @"Cyclic disk request list"];
      flags = [_memory readWord: pointer + 37];
      increment = (flags & 0x80) != 0;
      buffer = db_swap ([_memory readWord: pointer + 35]);
      coordinates = [_memory readWord: pointer + 36];
      if ((coordinates & 255) == 0xe0)
        buffer |= (uint32_t) (coordinates >> 8) << 16;
      else if ((coordinates & 255) == 0xf0)
        buffer *= 256;
      else if ((coordinates & 255) != 0xe1 && (coordinates & 255) != 0)
        [self hardwareError: @"Invalid disk transfer address type"];
      count = db_swap ([_memory readWord: pointer + 38]);
      negative = db_swap ([_memory readWord: dob + 2]);
      cylinder = db_swap ([_memory readWord: dob + 16]);
      coordinates = [_memory readWord: dob + 17];
      sector = (cylinder * [_disk heads] + (coordinates & 255)) * 16
               + (coordinates >> 8);
      lastSector = sector;
      labelPage = db_swap ([_memory readWord: dob + 28])
                  | ((uint32_t) ([_memory readWord: dob + 29] >> 8) << 16);
      operation = [_memory readWord: dob + 21] >> 8;
      if ([_memory physicalWord: 0x2229] != 0)
        error = 0x8c;
      if (operation != 0
          && (operation < 2 || operation > 7 ||
              [_memory readWord: pointer + 32] != 0))
        error = 0x8a;
      for (i = 10; i <= 13; i++)
        [_memory writeWord: dob + i value: 0];
      [_memory writeWord: pointer + 8 value: 0x4100];
      [_memory writeWord: pointer + 9 value: 0];
      while (count != 0 && operation != 0 && error == 0)
        {
          if (sector >= [_disk sectorCount])
            {
              error = 0x81;
              break;
            }
          [_memory writeWord: dob + 28 value: db_swap (labelPage + completed)];
          [_memory writeWord: dob + 29
                       value: (((labelPage + completed) >> 16) << 8)
                             | ([_memory readWord: dob + 29] & 255)];
          if (operation == 5 || operation == 6)
            for (i = 0; i < 10; i++)
              [_memory writeWord: dob + 23 + i
                           value: [_disk wordAtSector: sector offset: i]];
          else if (operation == 4)
            for (i = 0; i < 10; i++)
              [_disk writeSector: sector
                          offset: i
                           value: [_memory readWord: dob + 23 + i]];
          else
            {
              for (i = 0; i < 8; i++)
                if (i != 5 && i != 6 &&
                    [_disk wordAtSector: sector offset: i] !=
                        [_memory readWord: dob + 23 + i])
                  {
                    error = 0x23;
                    break;
                  }
              if (error)
                break;
            }
          for (i = 0; i < 256 && operation != 5; i++)
            {
              if (operation == 2 || operation == 6)
                [_memory writeWord: buffer + i
                             value: [_disk wordAtSector: sector offset: i + 10]];
              else if (operation == 3 || operation == 4)
                [_disk writeSector: sector
                            offset: i + 10
                             value: [_memory readWord: buffer + i]];
              else if ([_memory readWord: buffer + i] !=
                       [_disk wordAtSector: sector offset: i + 10])
                error = 0x33;
            }
          if (operation == 3 || operation == 4)
            _diskWrites++;
          else
            _diskReads++;
          lastSector = sector++;
          count--;
          completed++;
          negative++;
          if (increment)
            buffer += 256;
        }
      [_memory writeWord: pointer + 38 value: db_swap (count)];
      [_memory writeWord: dob + 2 value: db_swap (negative)];
      [_memory writeWord: dob + 14
                   value: db_swap (sector / ([_disk heads] * 16))];
      [_memory writeWord: dob + 16
                   value: db_swap (lastSector / ([_disk heads] * 16))];
      [_memory writeWord: dob + 17
                   value: ((lastSector % 16) << 8)
                         | ((lastSector / 16) % [_disk heads])];
      [_memory writeWord: dob + 18 value: 0xffff];
      [_memory
          writeWord: dob + 20
              value: 0x1280 | (cylinder || (coordinates & 255) ? 0x400 : 0)];
      [_memory writeWord: pointer + 35 value: db_swap (buffer)];
      [_memory
          writeWord: pointer + 36
              value: ((buffer >> 16) << 8) | (buffer > 65535 ? 0xe0 : 0xe1)];
      [_memory writeWord: pointer + 40 value: error ? 0xffff : 0];
      [_memory writeWord: pointer + 42 value: 0xff00];
      if (error)
        {
          [_memory writeWord: dob + 13 value: db_swap (error)];
          [_memory writeWord: pointer + 8
                       value: error == 0x8c ? 0x6190 : 0x6110];
          [_memory writeWord: pointer + 9
                       value: error == 0x81   ? 0x8000
                             : error == 0x23 ? 0x0800
                             : error == 0x33 ? 0x0080
                                             : 0];
          if (error == 0x23 || error == 0x33)
            [_memory writeWord: dob + 11 value: db_swap (error)];
        }
      if (error || ([_memory readWord: pointer + 39] & 0xff00))
        [_memory writePhysicalWord: 0x2229 value: 0xffff];
      pointer = db_swap ([_memory readWord: pointer + 13]);
    }
  if (requests != 0)
    [self requestInterrupt: [_memory physicalWord: 0x2246]];
}
- (BOOL) dispatch: (uint8_t)opcode escape: (BOOL)escape execute: (BOOL)execute
{
  uint16_t a, value, mask, operation;
  uint32_t address;
  if (!escape
      || !(opcode == 0x2f || (opcode >= 0x86 && opcode <= 0x89)
           || opcode == 0x8b || opcode == 0x8d))
    return [super dispatch: opcode escape: escape execute: execute];
  if (!execute)
    return YES;
  switch (opcode)
    {
    case 0x2f:
      [self push: 0x8002];
      [self push: 0x8482];
      break;
    case 0x86:
      [self popLong];
      break;
    case 0x87:
      a = [self pop];
      [self push: db_swap (a)];
      break;
    case 0x89:
      [self notifyDevice: [self pop]];
      break;
    case 0x88:
      mask = [self pop];
      value = [self pop];
      address = 0x2000 + (uint16_t) [self pop];
      operation = [self pop];
      if (address >= 0x6000)
        [self hardwareError: @"LOCKMEM outside IO region"];
      a = [_memory physicalWord: address];
      switch (operation)
        {
        case 0:
          value += a;
          break;
        case 1:
          value &= a;
          break;
        case 2:
          value |= a;
          break;
        case 3:
          break;
        case 4:
          if (a != 0)
            value = a;
          break;
        default:
          [self hardwareError: @"Invalid LOCKMEM operation"];
        }
      [_memory writePhysicalWord: address value: value];
      if (mask == [_memory physicalWord: 0x21c1])
        {
          if (value == 0x00f8)
            _displayEnabled = YES;
          else if (value & 8)
            _displayEnabled = NO;
          [_memory writePhysicalWord: 0x21c2 value: 0];
        }
      if (mask == [_memory physicalWord: 0x22ff])
        {
          if (address == 0x2303)
            [_memory writePhysicalWord: 0x2302 value: 0];
          if (address == 0x2305)
            [_memory writePhysicalWord: 0x2304 value: 0];
        }
      if (mask == [_memory physicalWord: 0x228c] && address == 0x2299)
        [_memory writePhysicalWord: 0x22e3 value: 0];
      [self push: a];
      break;
    case 0x8b:
      [self popLong];
      _halted = YES;
      break;
    case 0x8d:
      _halted = YES;
      break;
    }
  return YES;
}
@end
