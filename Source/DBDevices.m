/* Draco Ethernet and floppy IOP operations. Derived from Dwarf. See COPYING.
 */
#import "DBMachine.h"
#import "DBProcessorPrivate.h"
#include <string.h>
static uint16_t
db_device_swap (uint16_t v)
{
  return (v << 8) | (v >> 8);
}
static uint32_t
db_opie (DBMemory *memory, uint32_t at, BOOL physical)
{
  uint16_t a = physical ? [memory physicalWord: at] : [memory readWord: at];
  uint16_t b
      = physical ? [memory physicalWord: at + 1] : [memory readWord: at + 1];
  uint32_t low = db_device_swap (a);
  if ((b & 255) == 0xf0)
    return low * 256;
  if ((b & 255) == 0xe1)
    return low;
  if ((b & 255) == 0xe0 || (b & 255) == 0)
    return low | ((uint32_t) (b >> 8) << 16);
  [NSException raise: @"DBDeviceError"
              format: @"Unsupported IOP address type %02x", b & 255];
  return 0;
}
/* Preflight DMA before any writes so invalid guest buffers fail as device I/O,
   without a partially completed CPU instruction or partial sector update. */
static NSData *
db_dma_read (DBMemory *m, uint32_t at, unsigned int count)
{
  NSMutableData *data = [NSMutableData dataWithLength: count];
  unsigned char *bytes = [data mutableBytes];
  unsigned int i;
  for (i = 0; i < count; i += 2)
    {
      uint16_t w = [m readWord: at + i / 2];
      bytes[i] = w >> 8;
      if (i + 1 < count)
        bytes[i + 1] = w;
    }
  return data;
}
static void
db_dma_write (DBMemory *m, uint32_t at, NSData *data, unsigned int count)
{
  const unsigned char *bytes = [data bytes];
  unsigned int i;
  for (i = 0; i < count; i += 2)
    [m validateWord: at + i / 2 writing: YES];
  for (i = 0; i < count; i += 2)
    {
      uint16_t w = bytes[i] << 8;
      /* Preserve the byte beyond an odd-sized receive buffer. */
      w |= (i + 1 < count) ? bytes[i + 1] : ([m readWord: at + i / 2] & 255);
      [m writeWord: at + i / 2 value: w];
    }
}
@interface DBMachine (DevicePrivate)
- (void) updateFloppyState;
- (void) completeFloppy: (uint32_t)iocb;
@end
@implementation DBMachine (Devices)
- (DBFloppy *) floppy
{
  return _floppy;
}
- (DBNetwork *) network
{
  return _network;
}
- (uint64_t) packetsSent
{
  return _packetsSent;
}
- (uint64_t) packetsReceived
{
  return _packetsReceived;
}
- (void) setNetworkHost: (NSString *)host port: (unsigned int)port
{
  DBNetwork *next
      = host == nil ? nil : [[DBNetwork alloc] initWithHost: host port: port];
  [_network release];
  _network = next;
}
- (void) setHostID: (NSString *)identifier
{
  NSString *text = [[identifier stringByReplacingOccurrencesOfString: @":"
                                                          withString: @""]
      stringByReplacingOccurrencesOfString: @"-"
                                withString: @""];
  unsigned char bytes[6];
  unsigned int i;
  BOOL nonzero = NO;
  if ([text length] != 12)
    [NSException raise: NSInvalidArgumentException
                format: @"Ethernet ID needs twelve hexadecimal digits"];
  for (i = 0; i < 6; i++)
    {
      unsigned int j, value = 0;
      for (j = 0; j < 2; j++)
        {
          unichar c = [text characterAtIndex: i * 2 + j];
          if (c >= '0' && c <= '9')
            c -= '0';
          else if (c >= 'a' && c <= 'f')
            c = c - 'a' + 10;
          else if (c >= 'A' && c <= 'F')
            c = c - 'A' + 10;
          else
            [NSException raise: NSInvalidArgumentException
                        format: @"Invalid Ethernet ID"];
          value = (value << 4) | c;
        }
      bytes[i] = value;
      nonzero |= value != 0;
    }
  if (!nonzero || (bytes[0] & 1))
    [NSException raise: NSInvalidArgumentException
                format: @"Ethernet ID must be nonzero and unicast"];
  for (i = 0; i < 3; i++)
    _hostID[i] = (bytes[i * 2] << 8) | bytes[i * 2 + 1];
}
- (void) updateFloppyState
{
  BOOL present = _floppy != nil;
  uint16_t old = [_memory physicalWord: 0x22a5];
  [_memory
      writePhysicalWord: 0x22a5
                  value: (old & 0x4000) | (present ? 0x8000 : 0)
                        | ((present && [_floppy heads] == 2) ? 0x2000 : 0)];
  [_memory writePhysicalWord: 0x22a6 value: 0];
  [_memory writePhysicalWord: 0x22ab value: present ? 0 : 0xffff];
  [_memory
      writePhysicalWord: 0x22ac
                  value: 0x1000
                        | ((!present || [_floppy readOnly]) ? 0x4000 : 0)
                        | (present ? 0x2000 : 0)
                        | ((present && [_floppy heads] == 2) ? 0x0800 : 0)];
  if (present)
    {
      [_memory writePhysicalWord: 0x22a2 value: [_floppy cylinders]];
      [_memory writePhysicalWord: 0x22a3
                           value: ([_floppy heads] << 8) |
                                 [_floppy sectorsAtCylinder: 0 head: 0]];
    }
}
- (void) ejectFloppyDiscardingChanges: (BOOL)discard
{
  if (!discard && ([_floppy changed] || [_pendingFloppy changed]))
    [NSException raise: @"DBFloppyError"
                format: @"Export changed floppy media before ejecting"];
  [_floppy release];
  _floppy = nil;
  [_pendingFloppy release];
  _pendingFloppy = nil;
  _insertFloppyAt = [self intervalTimer] + 31250;
  [_memory writePhysicalWord: 0x22a7 value: 0xffff];
  [_memory writePhysicalWord: 0x22a8 value: 0xffff];
  [_memory writePhysicalWord: 0x22a5 value: 0x4000];
  [self updateFloppyState];
}
- (void) insertFloppy: (NSString *)path readOnly: (BOOL)readOnly
{
  DBFloppy *next;
  BOOL replacing = _floppy != nil || _pendingFloppy != nil;
  uint32_t previousInsertAt = _insertFloppyAt, now = [self intervalTimer];
  if ([_floppy changed] || [_pendingFloppy changed])
    [NSException raise: @"DBFloppyError"
                format: @"Export changed floppy media before replacing it"];
  next = [[DBFloppy alloc] initWithPath: path readOnly: readOnly];
  [self ejectFloppyDiscardingChanges: YES];
  _pendingFloppy = next;
  if (!replacing)
    _insertFloppyAt
        = (int32_t) (previousInsertAt - now) > 0 ? previousInsertAt : now;
  [self pollDevices];
}
- (void) pollDevices
{
  if (_pendingFloppy != nil
      && (int32_t) ([self intervalTimer] - _insertFloppyAt) >= 0)
    {
      _floppy = _pendingFloppy;
      _pendingFloppy = nil;
      [_memory writePhysicalWord: 0x22a7 value: 0xffff];
      [_memory writePhysicalWord: 0x22a8 value: 0xffff];
      [_memory writePhysicalWord: 0x22a5 value: 0x4000];
      [self updateFloppyState];
    }
  [_network poll];
  if (_receiveStopped)
    {
      [_network discardReceivedPackets];
      return;
    }
  while ([_receiveIOCBs count] != 0)
    {
      NSData *packet = [_network receivePacket];
      uint32_t iocb;
      volatile uint16_t status;
      if (packet == nil)
        break;
      iocb = [[_receiveIOCBs objectAtIndex: 0] unsignedIntValue];
      [_receiveIOCBs removeObjectAtIndex: 0];
      status = [_memory readWord: iocb + 6] & 0x0fff;
      NS_DURING
      unsigned int capacity = db_device_swap ([_memory readWord: iocb + 9]);
      unsigned int count = MIN (capacity, [packet length]);
      uint32_t buffer = db_opie (_memory, iocb + 7, NO);
      if (buffer == 0)
        [NSException raise: @"DBDeviceError" format: @"Null receive buffer"];
      db_dma_write (_memory, buffer, packet, count);
      [_memory writeWord: iocb + 10 value: db_device_swap (count)];
      status |= count == [packet length] ? 0x2000 : 0x1000;
      _packetsReceived++;
      NS_HANDLER
      status &= ~0x2000;
      [_memory writeWord: iocb + 10 value: 0];
      [_memory writeWord: iocb + 5 value: 0x9010];
      NS_ENDHANDLER
      [_memory writeWord: iocb + 6 value: status | 0xc000];
      [self requestInterrupt: [_memory readWord: iocb + 4]];
    }
}
- (void) serviceNetwork: (BOOL)input
{
  uint32_t pointer;
  NSMutableSet *visited = [NSMutableSet set];
  BOOL on = [_memory physicalWord: 0x22f4] != 0;
  [_memory writePhysicalWord: 0x2300 value: on];
  [_memory writePhysicalWord: 0x2301 value: on];
  if (!on)
    {
      _receiveStopped = YES;
      [_receiveIOCBs removeAllObjects];
      [_network discardReceivedPackets];
      return;
    }
  _receiveStopped = NO;
  if (_receiveIOCBs == nil)
    _receiveIOCBs = [NSMutableArray new];
  pointer = db_opie (_memory, input ? 0x22ee : 0x22e8, YES);
  while (pointer != 0)
    {
      NSNumber *key = [NSNumber numberWithUnsignedInt: pointer];
      volatile uint16_t status = [_memory readWord: pointer + 6];
      unsigned int type = (status >> 4) & 15;
      if ([visited containsObject: key] || [visited count] >= 4096)
        [self hardwareError: @"Cyclic or excessive Ethernet queue"];
      [visited addObject: key];
      if (!(status & 8))
        {
          if (input && type == 15)
            {
              NSUInteger i = 0;
              uint32_t buffer = db_opie (_memory, pointer + 7, NO);
              /* A reposted receive buffer replaces its previous pending IOCB.
               */
              while (i < [_receiveIOCBs count])
                {
                  uint32_t old =
                      [[_receiveIOCBs objectAtIndex: i] unsignedIntValue];
                  if (old == pointer
                      || db_opie (_memory, old + 7, NO) == buffer)
                    [_receiveIOCBs removeObjectAtIndex: i];
                  else
                    i++;
                }
              if ([_receiveIOCBs count] >= 4096)
                [self hardwareError: @"Too many Ethernet receive buffers"];
              [_receiveIOCBs addObject: key];
              [_memory writeWord: pointer + 6 value: status & 0x0fff];
            }
          else if (!input)
            {
              status = (status & 0x0fff) | 0xc000;
              [_memory writeWord: pointer + 5 value: 0x8000];
              if (type == 1)
                {
                  [_memory writeWord: pointer + 10 value: 0];
                  NS_DURING
                  unsigned int length
                      = db_device_swap ([_memory readWord: pointer + 9]);
                  uint32_t buffer = db_opie (_memory, pointer + 7, NO);
                  if (length > 766)
                    status |= 0x1000;
                  else if (length < 14 || !buffer)
                    [_memory writeWord: pointer + 5 value: 0x9010];
                  else if ([_network sendPacket: db_dma_read (_memory, buffer,
                                                             length)])
                    {
                      status |= 0x2000;
                      [_memory writeWord: pointer + 10
                                   value: db_device_swap (length)];
                      _packetsSent++;
                    }
                  else
                    [_memory writeWord: pointer + 5 value: 0x902f];
                  NS_HANDLER
                  [_memory writeWord: pointer + 5 value: 0x9010];
                  NS_ENDHANDLER
                }
              else if (type == 0 || type == 3 || type == 2)
                {
                  status |= 0x2000;
                  if (type == 2)
                    {
                      _receiveStopped = YES;
                      [_receiveIOCBs removeAllObjects];
                      [_network discardReceivedPackets];
                      [_memory writePhysicalWord: 0x2300 value: 0];
                      [_memory writePhysicalWord: 0x2301 value: 0];
                    }
                  else if (type == 3)
                    _receiveStopped = NO;
                }
              [_memory writeWord: pointer + 6 value: status];
              [self requestInterrupt: [_memory readWord: pointer + 4]];
            }
        }
      pointer = db_opie (_memory, pointer, NO);
    }
  [self pollDevices];
}
- (void) serviceFloppy
{
  uint32_t pointer;
  NSMutableSet *visited = [NSMutableSet set];
  uint16_t stopped = [_memory physicalWord: 0x2282] & 0xff00;
  [_memory writePhysicalWord: 0x2283 value: stopped];
  if (stopped)
    return;
  [self updateFloppyState];
  pointer = db_opie (_memory, 0x2295, YES);
  while (pointer)
    {
      NSNumber *key = [NSNumber numberWithUnsignedInt: pointer];
      if ([visited containsObject: key] || [visited count] >= 4096)
        [self hardwareError: @"Cyclic or excessive floppy queue"];
      [visited addObject: key];
      [self completeFloppy: pointer];
      pointer = db_opie (_memory, pointer + 12, NO);
    }
}
- (void) completeFloppy: (uint32_t)iocb
{
  unsigned int index
      = MIN (3, MAX (1, db_device_swap ([_memory readWord: iocb + 35]))) - 1;
  uint32_t cmd = iocb + 37 + index * 13;
  unsigned int op = [_memory readWord: iocb + 8] >> 8;
  volatile unsigned int c = [_memory readWord: cmd + 4] >> 8,
                        h = [_memory readWord: cmd + 4] & 255;
  volatile unsigned int sector = [_memory readWord: cmd + 5] >> 8,
                        code = [_memory readWord: cmd + 5] & 255;
  unsigned int first = db_device_swap ([_memory readWord: iocb + 23]);
  unsigned int middle = db_device_swap ([_memory readWord: iocb + 78]);
  unsigned int last = db_device_swap ([_memory readWord: iocb + 88]);
  volatile unsigned int result = 1, transferred = 0;
  volatile BOOL scanHit = NO, scanEqual = NO;
  [_memory writeWord: iocb + 36 value: db_device_swap (index + 1)];
  [_memory writeWord: cmd + 2
               value: ([_memory readWord: cmd + 2] & 0xff00)
                     | ([_memory readWord: cmd + 2] >> 8)];
  NS_DURING
  uint32_t buffer = 0;
  if (op == 1 || op == 2 || op == 3 || op == 5 || (op >= 7 && op <= 9)
      || op == 14 || op == 15)
    buffer = db_opie (_memory, iocb + 14, NO);
  if (([_memory readWord: iocb + 22] >> 8) != 0)
    result = 12;
  else if (op == 0 || op == 6 || op == 10 || op == 11 || op == 12 || op == 13)
    {
      if (op != 0 && _floppy == nil)
        result = 3;
    }
  else if (_floppy == nil)
    result = 3;
  else if (op == 4)
    {
      NSArray *ids;
      c = [_memory readWord: iocb + 2];
      h = [_memory readWord: iocb + 3] >> 8;
      ids = [_floppy sectorIDsAtCylinder: c head: h];
      if ([ids count] == 0)
        result = 6;
      else
        {
          unsigned int size;
          sector = [[ids objectAtIndex: 0] unsignedIntValue];
          size = (unsigned int) [[_floppy sectorAtCylinder: c
                                                      head: h
                                                    sector: sector] length];
          code = 0;
          while ((128U << code) < size)
            code++;
        }
    }
  else if (op == 1)
    {
      unsigned int count = [_memory readWord: cmd + 4] & 255;
      c = [_memory readWord: iocb + 2];
      h = [_memory readWord: iocb + 3] >> 8;
      if ([_memory readWord: iocb + 9] & 0x8000)
        result = 10;
      else
        result =
            [_floppy formatCylinder: c
                               head: h
                        descriptors: db_dma_read (_memory, buffer, count * 4)
                               fill: [_memory readWord: cmd + 5] & 255];
      if (result == 1)
        transferred = count * 4;
    }
  else if (op == 2 || op == 3 || op == 5 || (op >= 7 && op <= 9) || op == 14
           || op == 15)
    {
      unsigned int size = code <= 6 ? 128U << code : 0;
      unsigned int total = first + middle + last,
                   remaining = size ? total / size : 0;
      BOOL writing = op == 14 || op == 15;
      if (size == 0 || total % size || !remaining)
        result = 12;
      else if (writing
               && ([_floppy readOnly]
                   || ([_memory readWord: iocb + 9] & 0x8000)))
        result = 10;
      while (remaining && result == 1)
        {
          NSData *data = [_floppy sectorAtCylinder: c head: h sector: sector];
          unsigned int mediaStatus = [_floppy statusAtCylinder: c
                                                          head: h
                                                        sector: sector];
          if (c >= [_floppy cylinders])
            {
              result = 4;
              break;
            }
          if (data == nil || mediaStatus == 6)
            {
              result = 6;
              break;
            }
          if ([data length] != size)
            {
              result = 9;
              break;
            }
          if (writing)
            result = [_floppy writeCylinder: c
                                       head: h
                                     sector: sector
                                       data: db_dma_read (_memory, buffer, size)
                                    deleted: op == 15];
          else if (op >= 7 && op <= 9)
            {
              NSData *comparison = db_dma_read (_memory, buffer, size);
              const unsigned char *diskBytes = [data bytes],
                                  *cpuBytes = [comparison bytes];
              unsigned int n;
              int relation = 0;
              if (mediaStatus != 1)
                {
                  result = mediaStatus;
                  break;
                }
              for (n = 0; n < size; n++)
                if (cpuBytes[n] != 255 && diskBytes[n] != cpuBytes[n])
                  {
                    relation = diskBytes[n] < cpuBytes[n] ? -1 : 1;
                    break;
                  }
              scanEqual = relation == 0;
              scanHit = op == 7   ? relation == 0
                        : op == 8 ? relation >= 0
                                  : relation <= 0;
            }
          else
            {
              if (mediaStatus == 8)
                {
                  result = 8;
                  break;
                }
              db_dma_write (_memory, buffer, data, size);
              if (mediaStatus == 5 && op != 3)
                result = 5;
            }
          if (result != 1 && result != 5)
            break;
          transferred += size;
          remaining--;
          if (scanHit)
            break;
          if ([_memory readWord: iocb + 34] & 0xff00)
            buffer += size / 2;
          sector++;
          /* The controller's EOT is a sector ID, not the number of records
             in an IMD track; gaps must report record-not-found. */
          if (sector > ([_memory readWord: cmd + 6] >> 8))
            {
              sector = 1;
              if (++h >= [_floppy heads])
                {
                  h = 0;
                  c++;
                }
            }
        }
    }
  else
    result = 12;
  NS_HANDLER
  result = 11;
  NS_ENDHANDLER
  {
    unsigned int amount = MIN (first, transferred),
                 left = transferred - amount;
    uint16_t st0 = result == 1 ? 0 : result == 3 ? 0x48 : 0x40;
    uint16_t st1 = result == 10                  ? 2
                   : result == 6 || result == 4  ? 4
                   : result == 8                 ? 0x20
                   : result == 9 || result == 11 ? 0x10
                                                 : 0;
    [_memory writeWord: iocb + 24 value: db_device_swap (amount)];
    [_memory writeWord: iocb + 33 value: db_device_swap ((uint16_t) -amount)];
    amount = MIN (middle, left);
    left -= amount;
    [_memory writeWord: iocb + 79 value: db_device_swap (amount)];
    [_memory writeWord: iocb + 89 value: db_device_swap (MIN (last, left))];
    [_memory writeWord: iocb + 8 value: (op << 8) | result];
    [_memory writeWord: iocb + 11 value: result == 1 ? 6 : 7];
    [_memory writeWord: iocb + 10
                 value: ([_memory readWord: iocb + 10] & 0xff00) | 1];
    [_memory writeWord: iocb + 22 value: [_memory readWord: iocb + 22] & 0xff00];
    [_memory writeWord: cmd + 8
                 value: ([_memory readWord: cmd + 8] & 0xff00)
                       | ([_memory readWord: cmd + 8] >> 8)];
    [_memory writeWord: cmd + 9 value: (st0 << 8) | st1];
    [_memory writeWord: cmd + 10
                 value: ((op >= 7 && op <= 9 && result == 1
                             ? (scanHit ? (scanEqual ? 8 : 0) : 4)
                         : result == 5 ? 0x40
                         : result == 8 ? 0x20
                                       : 0)
                        << 8)
                       | (c & 255)];
    [_memory writeWord: cmd + 11 value: (h << 8) | (sector & 255)];
    [_memory writeWord: cmd + 12 value: code << 8];
    [self requestInterrupt: [_memory readWord: iocb + 18]];
  }
}
@end
