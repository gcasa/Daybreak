/* Device regression fixtures contain no Xerox software. See COPYING. */
#import "DBMachine.h"
#import "DBProcessorPrivate.h"
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
static unsigned int checks;
#define CHECK(x)                                                              \
  do                                                                          \
    {                                                                         \
      checks++;                                                               \
      if (!(x))                                                               \
        {                                                                     \
          fprintf (stderr, "FAIL %s:%d %s\n", __FILE__, __LINE__, #x);        \
          exit (1);                                                           \
        }                                                                     \
    }                                                                         \
  while (0)
static uint16_t
sw (uint16_t v)
{
  return (v << 8) | (v >> 8);
}
static void
opie (DBMemory *m, uint32_t at, uint32_t pointer, BOOL physical)
{
  if (physical)
    {
      [m writePhysicalWord: at value: sw (pointer)];
      [m writePhysicalWord: at + 1 value: ((pointer >> 16) << 8) | 0xe0];
    }
  else
    {
      [m writeWord: at value: sw (pointer)];
      [m writeWord: at + 1 value: ((pointer >> 16) << 8) | 0xe0];
    }
}
static void
append_byte (NSMutableData *data, unsigned int v)
{
  unsigned char b = v;
  [data appendBytes: &b length: 1];
}
static NSString *
make_imd (NSString *directory)
{
  const char header[] = "IMD synthetic mixed density\r\n\x1a";
  NSMutableData *data = [NSMutableData dataWithBytes: header
                                              length: sizeof (header) - 1];
  unsigned int c, h, s;
  NSString *path = [directory stringByAppendingPathComponent: @"fixture.imd"];
  for (c = 0; c < 2; c++)
    for (h = 0; h < 2; h++)
      {
        append_byte (data, c ? 5 : 2);
        append_byte (data, c);
        append_byte (data, h);
        append_byte (data, 2);
        append_byte (data, c ? 2 : h ? 1 : 0);
        append_byte (data, 2);
        append_byte (data, 1); /* Interleaved physical order. */
        for (s = 0; s < 2; s++)
          {
            append_byte (data, 2);
            append_byte (data, 0xa0 + c * 16 + h * 4 + s);
          }
      }
  CHECK ([data writeToFile: path atomically: YES]);
  return path;
}
static NSString *
make_dmk (NSString *directory)
{
  NSMutableData *data = [NSMutableData dataWithLength: 16 + 1024];
  unsigned char *b = [data mutableBytes], *t = b + 16;
  unsigned int i;
  NSString *path = [directory stringByAppendingPathComponent: @"fixture.dmk"];
  b[0] = 0xff;
  b[1] = 1;
  b[2] = 0;
  b[3] = 4;
  b[4] = 0x10;
  t[0] = 128;
  t[1] = 0; /* FM, doubled bytes. */
  t[128] = t[129] = 0xfe;
  t[130] = t[131] = 0;
  t[132] = t[133] = 0;
  t[134] = t[135] = 1;
  t[136] = t[137] = 0;
  t[150] = t[151] = 0xfb;
  for (i = 0; i < 128; i++)
    t[152 + i * 2] = t[153 + i * 2] = i;
  CHECK ([data writeToFile: path atomically: YES]);
  return path;
}
static void
model_tests (NSString *directory, NSString *path)
{
  DBFloppy *f = [[DBFloppy alloc] initWithPath: path readOnly: NO], *copy;
  NSData *original = [NSData dataWithContentsOfFile: path];
  NSString *out = [directory stringByAppendingPathComponent: @"export.imd"];
  NSMutableData *sector = [NSMutableData dataWithLength: 128];
  unsigned char format[] = { 0, 0, 1, 0, 0, 0, 2, 0 };
  CHECK ([f cylinders] == 2 && [f heads] == 2);
  CHECK ([f sectorsAtCylinder: 0 head: 0] == 2);
  CHECK (((const unsigned char *) [[f sectorAtCylinder: 0 head: 0
                                                sector: 1] bytes])[0]
         == 0xa1);
  CHECK ([[f sectorAtCylinder: 0 head: 1 sector: 1] length] == 256);
  CHECK ([[f sectorAtCylinder: 1 head: 0 sector: 2] length] == 512);
  CHECK ([f sectorAtCylinder: 2 head: 0 sector: 1] == nil);
  memset ([sector mutableBytes], 0x55, 128);
  CHECK ([f writeCylinder: 0 head: 0 sector: 1 data: sector deleted: YES] == 1);
  CHECK ([f statusAtCylinder: 0 head: 0 sector: 1] == 5 && [f changed]);
  [f saveCopyToPath: out];
  CHECK (![f changed]);
  CHECK ([[NSData dataWithContentsOfFile: path] isEqual: original]);
  copy = [[DBFloppy alloc] initWithPath: out readOnly: YES];
  CHECK ([[copy sectorAtCylinder: 0 head: 0 sector: 1] isEqual: sector]);
  CHECK ([copy statusAtCylinder: 0 head: 0 sector: 1] == 5);
  CHECK ([copy writeCylinder: 0 head: 0 sector: 1 data: sector deleted: NO] == 10);
  [copy release];
  CHECK ([f formatCylinder: 0
                      head: 0
               descriptors: [NSData dataWithBytes: format length: sizeof (format)]
                      fill: 0xe5]
         == 1);
  CHECK (((const unsigned char *) [[f sectorAtCylinder: 0 head: 0
                                                sector: 2] bytes])[127]
         == 0xe5);
  format[6] = 1;
  CHECK ([f formatCylinder: 0
                      head: 0
               descriptors: [NSData dataWithBytes: format length: sizeof (format)]
                      fill: 0]
         == 12);
  CHECK ([f sectorsAtCylinder: 0 head: 0] == 2);
  {
    volatile BOOL caught = NO;
    NS_DURING [f saveCopyToPath: path];
    NS_HANDLER caught = YES;
    NS_ENDHANDLER
    CHECK (caught);
  }
  [f release];
  copy = [[DBFloppy alloc] initWithPath: make_dmk (directory) readOnly: NO];
  CHECK ([copy readOnly] && [copy cylinders] == 1 && [copy heads] == 1);
  CHECK (((const unsigned char *) [[copy sectorAtCylinder: 0 head: 0
                                                   sector: 1] bytes])[127]
         == 127);
  [copy saveCopyToPath: out];
  [copy release];
  copy = [[DBFloppy alloc] initWithPath: out readOnly: YES];
  CHECK (((const unsigned char *) [[copy sectorAtCylinder: 0 head: 0
                                                   sector: 1] bytes])[127]
         == 127);
  [copy release];
  {
    NSUInteger cuts[] = { 0, 3, 20, 35, 40 };
    volatile unsigned int i;
    for (i = 0; i < 5; i++)
      {
        volatile BOOL caught = NO;
        [[original
            subdataWithRange: NSMakeRange (
                                 0, MIN (cuts[i], [original length] - 1))]
            writeToFile: out
             atomically: YES];
        NS_DURING copy = [[DBFloppy alloc] initWithPath: out readOnly: NO];
        [copy release];
        NS_HANDLER caught = YES;
        NS_ENDHANDLER
        CHECK (caught);
      }
  }
}
static void
floppy_request (DBMemory *m, unsigned int op, unsigned int c, unsigned int h,
                unsigned int sector, unsigned int code, unsigned int count)
{
  unsigned int i;
  uint32_t p = 0x1000, cmd = p + 37;
  for (i = 0; i < 98; i++)
    [m writeWord: p + i value: 0];
  [m writeWord: p + 2 value: c];
  [m writeWord: p + 3 value: (h << 8) | sector];
  [m writeWord: p + 7 value: count];
  [m writeWord: p + 8 value: op << 8];
  [m writeWord: p + 11 value: 0xff03];
  opie (m, p + 14, 0x3000, NO);
  [m writeWord: p + 18 value: 4];
  [m writeWord: p + 23 value: sw (count * (128U << code))];
  [m writeWord: p + 34 value: 0xff00];
  [m writeWord: p + 35 value: sw (1)];
  [m writeWord: cmd value: op << 8];
  [m writeWord: cmd + 2 value: 0x0900];
  [m writeWord: cmd + 4 value: (c << 8) | h];
  [m writeWord: cmd + 5 value: (sector << 8) | code];
  [m writeWord: cmd + 6 value: 2 << 8];
  [m writeWord: cmd + 8 value: 0x0700];
  opie (m, 0x2295, p, YES);
}
static void
floppy_io_tests (DBMachine *machine, NSString *path, NSString *directory)
{
  DBMemory *m = [machine memory];
  unsigned int i;
  [machine insertFloppy: path readOnly: NO];
  CHECK ([machine floppy] != nil);
  CHECK (([m physicalWord: 0x22ac] & 0x6000) == 0x2000);
  CHECK ([m physicalWord: 0x22a8] == 0xffff);
  floppy_request (m, 2, 0, 0, 1, 0, 2);
  [machine serviceFloppy];
  CHECK ([m readWord: 0x100b] == 6 && ([m readWord: 0x1008] & 255) == 1);
  CHECK ([m readWord: 0x3000] == 0xa1a1 && [m readWord: 0x3040] == 0xa0a0);
  CHECK ([m readWord: 0x1018] == sw (256) &&
         [m readWord: 0x1021] == sw ((uint16_t) -256));
  CHECK (([machine state]->WP & 4) != 0);
  CHECK ([m readWord: 0x102f] == 0 &&
         [m readWord: 0x1030] == 0x101); /* next head/sector */
  for (i = 0; i < 64; i++)
    [m writeWord: 0x3000 + i value: 0x5678];
  floppy_request (m, 14, 0, 0, 1, 0, 1);
  [machine serviceFloppy];
  CHECK ([m readWord: 0x100b] == 6 && [[machine floppy] changed]);
  CHECK (((const unsigned char *) [[[machine floppy] sectorAtCylinder: 0
                                                                 head: 0
                                                               sector: 1]
             bytes])[0]
         == 0x56);
  floppy_request (m, 2, 0, 0, 1, 0, 1);
  [machine serviceFloppy];
  CHECK ([m readWord: 0x3000] == 0x5678);
  floppy_request (m, 7, 0, 0, 1, 0, 1);
  [machine serviceFloppy];
  CHECK (([m readWord: 0x102f] >> 8) == 8);
  [m writeWord: 0x3000 value: 0];
  floppy_request (m, 7, 0, 0, 1, 0, 1);
  [machine serviceFloppy];
  CHECK (([m readWord: 0x102f] >> 8) == 4);

  {
    volatile BOOL caught = NO;
    NS_DURING [machine ejectFloppyDiscardingChanges: NO];
    NS_HANDLER caught = YES;
    NS_ENDHANDLER
    CHECK (caught && [machine floppy] != nil);
  }
  [[machine floppy]
      saveCopyToPath: [directory
                         stringByAppendingPathComponent: @"io-copy.imd"]];
  [machine ejectFloppyDiscardingChanges: NO];
  floppy_request (m, 2, 0, 0, 1, 0, 1);
  [machine serviceFloppy];
  CHECK (([m readWord: 0x1008] & 255) == 3 && [m readWord: 0x100b] == 7);
  [machine insertFloppy: path readOnly: YES];
  CHECK ([machine floppy] == nil && [m physicalWord: 0x22ab] == 0xffff);
  [machine setIntervalTimer: [machine intervalTimer] + 31251];
  [machine pollDevices];
  CHECK ([machine floppy] != nil);
  floppy_request (m, 14, 0, 0, 1, 0, 1);
  [machine serviceFloppy];
  CHECK (([m readWord: 0x1008] & 255) == 10 && [m readWord: 0x102e] == 0x4002);
  floppy_request (m, 2, 0, 0, 9, 0, 1);
  [machine serviceFloppy];
  CHECK (([m readWord: 0x1008] & 255) == 6);
  floppy_request (m, 2, 0, 0, 1, 0, 1);
  opie (m, 0x100e, 0, NO);
  [machine serviceFloppy];
  CHECK (([m readWord: 0x1008] & 255) == 11);
  floppy_request (m, 4, 0, 0, 0, 0, 0);
  [machine serviceFloppy];
  CHECK ([m readWord: 0x100b] == 6 && [m readWord: 0x1030] == 1);
  [m writePhysicalWord: 0x2282 value: 0xff00];
  floppy_request (m, 2, 0, 0, 1, 0, 1);
  [machine serviceFloppy];
  CHECK ([m readWord: 0x100b] == 0xff03 && [m physicalWord: 0x2283] == 0xff00);
  [m writePhysicalWord: 0x2282 value: 0];
  [machine ejectFloppyDiscardingChanges: YES];
  [machine insertFloppy: path readOnly: NO];
  [machine setIntervalTimer: [machine intervalTimer] + 31251];
  [machine pollDevices];
  floppy_request (m, 15, 0, 0, 1, 0, 1);
  [machine serviceFloppy];
  CHECK ([[machine floppy] statusAtCylinder: 0 head: 0 sector: 1] == 5);
  floppy_request (m, 3, 0, 0, 1, 0, 1);
  [machine serviceFloppy];
  CHECK (([m readWord: 0x1008] & 255) == 1);
  floppy_request (m, 2, 0, 0, 1, 0, 1);
  [machine serviceFloppy];
  CHECK (([m readWord: 0x1008] & 255) == 5);
  floppy_request (m, 1, 0, 0, 1, 0, 1);
  [m writeWord: 0x1029 value: 2]; /* Format command N=0, SC=2. */
  [m writeWord: 0x102a value: 0xe5];
  [m writeWord: 0x3000 value: 0];
  [m writeWord: 0x3001 value: 0x0100];
  [m writeWord: 0x3002 value: 0];
  [m writeWord: 0x3003 value: 0x0200];
  [machine serviceFloppy];
  CHECK (([m readWord: 0x1008] & 255) == 1);
  CHECK (((const unsigned char *) [[[machine floppy] sectorAtCylinder: 0
                                                                 head: 0
                                                               sector: 1]
             bytes])[0]
         == 0xe5);
  floppy_request (m, 2, 1, 0, 1, 2, 3);
  [machine serviceFloppy];
  CHECK (([m readWord: 0x1008] & 255) == 1);
  CHECK ([m readWord: 0x3000] == 0xb1b1 && [m readWord: 0x3200] == 0xb5b5);
  {
    unsigned char ids[] = { 0, 0, 2, 0, 0, 0, 5, 0 };
    CHECK ([[machine floppy] formatCylinder: 0
                                       head: 0
                                descriptors: [NSData dataWithBytes: ids
                                                           length: sizeof (ids)]
                                       fill: 0xe5]
           == 1);
    floppy_request (m, 2, 0, 0, 2, 0, 2);
    [m writeWord: 0x102b value: 5 << 8];
    [machine serviceFloppy];
    CHECK (([m readWord: 0x1008] & 255) == 6 &&
           [m readWord: 0x1018] == sw (128));
    ids[2] = 1;
    ids[6] = 2;
    CHECK ([[machine floppy] formatCylinder: 0
                                       head: 0
                                descriptors: [NSData dataWithBytes: ids
                                                           length: sizeof (ids)]
                                       fill: 0xe5]
           == 1);
  }
  /* A protected DMA destination reports a device error, not a CPU fault. */
  floppy_request (m, 2, 0, 0, 1, 0, 1);
  [m mapPage: 0x30 to: 0x30 flags: DB_MAP_PROTECTED];
  [machine serviceFloppy];
  CHECK (([m readWord: 0x1008] & 255) == 11);
  [m mapPage: 0x30 to: 0x30 flags: 0];
  [machine ejectFloppyDiscardingChanges: YES];
}
static int
make_listener (unsigned int *port)
{
  struct sockaddr_in address;
  socklen_t length = sizeof (address);
  int fd = socket (AF_INET, SOCK_STREAM, 0);
  memset (&address, 0, sizeof (address));
  address.sin_family = AF_INET;
  address.sin_addr.s_addr = htonl (INADDR_LOOPBACK);
  CHECK (fd >= 0
         && bind (fd, (struct sockaddr *) &address, sizeof (address)) == 0
         && listen (fd, 4) == 0);
  CHECK (getsockname (fd, (struct sockaddr *) &address, &length) == 0);
  *port = ntohs (address.sin_port);
  fcntl (fd, F_SETFL, O_NONBLOCK);
  return fd;
}
static int
accept_client (int listener, DBNetwork *network)
{
  int fd = -1;
  unsigned int i;
  for (i = 0; i < 200 && (fd < 0 || ![network connected]); i++)
    {
      [network poll];
      if (fd < 0)
        fd = accept (listener, NULL, NULL);
      usleep (1000);
    }
  CHECK (fd >= 0 && [network connected]);
  fcntl (fd, F_SETFL, O_NONBLOCK);
  return fd;
}
static void
network_tests (DBMachine *machine)
{
  unsigned int port, i;
  int listener = make_listener (&port), peer;
  DBNetwork *network;
  DBMemory *m = [machine memory];
  unsigned char frame[34], received[64];
  ssize_t got = -1;
  for (i = 0; i < sizeof (frame); i++)
    frame[i] = i;
  frame[0] = 0;
  frame[1] = 15;
  frame[17] = 0;
  frame[18] = 15;
  [machine setNetworkHost: @"127.0.0.1" port: port];
  network = [machine network];
  peer = accept_client (listener, network);
  CHECK (send (peer, frame, 1, 0) == 1);
  [network poll];
  CHECK ([network receivePacket] == nil);
  CHECK (send (peer, frame + 1, 16, 0) == 16);
  for (i = 0; i < 200; i++)
    {
      [network poll];
      usleep (1000);
    }
  CHECK ([[network receivePacket] isEqual: [NSData dataWithBytes: frame + 2
                                                         length: 15]]);
  CHECK (send (peer, frame, sizeof (frame), 0) == sizeof (frame));
  for (i = 0; i < 50; i++)
    {
      [network poll];
      usleep (1000);
    }
  CHECK ([[network receivePacket] length] == 15 &&
         [[network receivePacket] length] == 15 &&
         [network receivePacket] == nil);
  [m writePhysicalWord: 0x22f4 value: 1];
  for (i = 0; i < 14; i++)
    {
      [m writeWord: 0x2000 + i value: 0];
      [m writeWord: 0x2100 + i value: 0];
    }
  opie (m, 0x22ee, 0x2100, YES);
  opie (m, 0x2100, 0x2000, NO);
  [m writeWord: 0x2106 value: 0xf8]; /* dontProcess must still advance. */
  [m writeWord: 0x2006 value: 0xf0];
  [m writeWord: 0x2004 value: 8];
  opie (m, 0x2007, 0x4000, NO);
  [m writeWord: 0x2009 value: sw (15)];
  [m writeWord: 0x4007 value: 0x00aa];
  [machine serviceNetwork: YES];
  [machine serviceNetwork: YES];
  CHECK (send (peer, frame, 17, 0) == 17);
  for (i = 0; i < 100 && !([m readWord: 0x2006] & 0x8000); i++)
    {
      [machine pollDevices];
      usleep (1000);
    }
  CHECK (([m readWord: 0x2006] & 0xe000) == 0xe000);
  CHECK ([m readWord: 0x200a] == sw (15) && [m readWord: 0x4007] == 0x10aa);
  CHECK (([machine state]->WP & 8) != 0 && [machine packetsReceived] == 1);
  [machine pollDevices];
  CHECK ([machine packetsReceived] == 1);
  /* Outgoing data reaches the TCP peer, and its completion interrupts guest.
   */
  opie (m, 0x22e8, 0x2200, YES);
  for (i = 0; i < 14; i++)
    [m writeWord: 0x2200 + i value: 0];
  [m writeWord: 0x2206 value: 0x10];
  [m writeWord: 0x2204 value: 16];
  opie (m, 0x2207, 0x4000, NO);
  [m writeWord: 0x2209 value: sw (15)];
  [machine serviceNetwork: NO];
  for (i = 0; i < 100 && got < 0; i++)
    {
      [machine pollDevices];
      got = recv (peer, received, sizeof (received), 0);
      usleep (1000);
    }
  CHECK (got == 17 && received[0] == 0 && received[1] == 15
         && memcmp (received + 2, frame + 2, 15) == 0);
  CHECK ([m readWord: 0x2206] == 0xe010 && [m readWord: 0x220a] == sw (15));
  CHECK (([machine state]->WP & 16) != 0 && [machine packetsSent] == 1);
  /* Short receive buffers report truncation and never touch the next byte. */
  [m writeWord: 0x2009 value: sw (3)];
  [m writeWord: 0x4001 value: 0x00cc];
  [machine serviceNetwork: YES];
  CHECK (send (peer, frame, 17, 0) == 17);
  for (i = 0; i < 100 && !([m readWord: 0x2006] & 0x8000); i++)
    {
      [machine pollDevices];
      usleep (1000);
    }
  CHECK (([m readWord: 0x2006] & 0xf000) == 0xd000 &&
         [m readWord: 0x200a] == sw (3) && [m readWord: 0x4001] == 0x04cc);
  /* Oversize frames fail without reading beyond guest buffer. */
  [m writeWord: 0x2209 value: sw (767)];
  [machine serviceNetwork: NO];
  CHECK (([m readWord: 0x2206] & 0xf000) == 0xd000);
  /* Reset cancels receive requests. */
  [machine serviceNetwork: YES];
  [m writeWord: 0x2206 value: 0x20];
  [machine serviceNetwork: NO];
  CHECK ([m physicalWord: 0x2300] == 0 && [m physicalWord: 0x2301] == 0);
  CHECK (send (peer, frame, 17, 0) == 17);
  [machine pollDevices];
  CHECK (!([m readWord: 0x2006] & 0x8000));
  /* Queue bound, malformed framing and disconnect are host-safe. */
  for (i = 0; i < 64; i++)
    CHECK ([network sendPacket: [NSData dataWithBytes: frame + 2 length: 15]]);
  CHECK (![network sendPacket: [NSData dataWithBytes: frame + 2 length: 15]]);
  {
    unsigned char bad[2] = { 255, 255 };
    CHECK (send (peer, bad, 2, 0) == 2);
  }
  for (i = 0; i < 100 && [network connected]; i++)
    {
      [network poll];
      usleep (1000);
    }
  CHECK (![network connected]);
  close (peer);
  /* A failed connection is re-established without restarting the machine. */
  for (i = 0; i < 2500 && ![network connected]; i++)
    {
      [network poll];
      usleep (1000);
    }
  CHECK ([network connected]);
  peer = accept_client (listener, network);
  close (peer);
  close (listener);
  [machine setNetworkHost: nil port: 0];
  CHECK ([machine network] == nil);
}
int
main (int argc, char **argv)
{
#ifdef GNUSTEP
  extern char **environ;
  GSInitializeProcess (argc, argv, environ);
#endif
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  NSString *directory = [NSTemporaryDirectory ()
      stringByAppendingPathComponent: [[NSProcessInfo processInfo]
                                         globallyUniqueString]];
  DBMemory *memory = [[DBMemory alloc] initWithRealPages: 8192
                                            virtualPages: 65536];
  DBMachine *machine = [[DBMachine alloc] initWithMemory: memory post40: NO];
  NSString *path;
  (void) argc;
  (void) argv;
  CHECK ([[NSFileManager defaultManager] createDirectoryAtPath: directory
                                   withIntermediateDirectories: YES
                                                    attributes: nil
                                                         error: NULL]);
  path = make_imd (directory);
  model_tests (directory, path);
  floppy_io_tests (machine, path, directory);
  network_tests (machine);
  [machine release];
  [memory release];
  [[NSFileManager defaultManager] removeItemAtPath: directory error: NULL];
  printf ("Passed %u device checks\n", checks);
  [pool release];
  return 0;
}
