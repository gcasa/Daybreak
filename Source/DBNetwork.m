/* NetHub protocol derived from Dwarf. See COPYING. */
#import "DBNetwork.h"
#include <sys/types.h>
#include <sys/socket.h>
#include <netdb.h>
#include <fcntl.h>
#include <unistd.h>
#include <errno.h>
#include <string.h>
#include <poll.h>
#include <time.h>

static double
db_net_time (void)
{
  struct timespec t;
  clock_gettime (CLOCK_MONOTONIC, &t);
  return t.tv_sec + t.tv_nsec / 1000000000.0;
}
#include <sys/ioctl.h>
#ifdef __linux__
#include <linux/if.h>
#include <linux/if_tun.h>
#endif
static uint16_t
db_packet_word (const unsigned char *p, unsigned int word)
{
  return (p[word * 2] << 8) | p[word * 2 + 1];
}
static NSData *
db_local_response (NSData *packet)
{
  const unsigned char *p = [packet bytes];
  uint16_t words[37];
  unsigned int i;
  uint32_t now;
  NSMutableData *data;
  unsigned char *bytes;
  if ([packet length] < 46 || db_packet_word (p, 6) != 0x600
      || db_packet_word (p, 8) < 32
      || db_packet_word (p, 8) > [packet length] - 14)
    return nil;
  if ((db_packet_word (p, 9) & 255) == 2 && db_packet_word (p, 22) == 1)
    {
      unsigned char address[12];
      data = [[packet mutableCopy] autorelease];
      bytes = [data mutableBytes];
      memcpy (address, bytes, 6);
      memcpy (bytes, bytes + 6, 6);
      memcpy (bytes + 6, address, 6);
      memcpy (address, bytes + 20, 12);
      memcpy (bytes + 20, bytes + 32, 12);
      memcpy (bytes + 32, address, 12);
      bytes[14] = bytes[15] = 255;
      bytes[44] = 0;
      bytes[45] = 2;
      return data;
    }
  if ([packet length] < 54 || db_packet_word (p, 15) != 8
      || (db_packet_word (p, 9) & 255) != 4 || db_packet_word (p, 24) != 1
      || db_packet_word (p, 25) != 2 || db_packet_word (p, 26) != 1)
    return nil;
  memset (words, 0, sizeof (words));
  for (i = 0; i < 3; i++)
    words[i] = db_packet_word (p, i + 3);
  words[3] = 0x1000;
  words[4] = 0x1a33;
  words[5] = 0x3333;
  words[6] = 0x600;
  words[7] = 65535;
  words[8] = 60;
  words[9] = 4;
  for (i = 0; i < 6; i++)
    words[10 + i] = db_packet_word (p, 16 + i);
  words[16] = 4;
  words[17] = 1;
  words[18] = words[3];
  words[19] = words[4];
  words[20] = words[5];
  words[21] = 8;
  words[22] = db_packet_word (p, 22);
  words[23] = db_packet_word (p, 23);
  words[24] = 1;
  words[25] = 2;
  words[26] = 2;
  now = (uint32_t) time (NULL) + 2177452800U;
  words[27] = now >> 16;
  words[28] = now;
  words[34] = 1;
  data = [NSMutableData dataWithLength: sizeof (words)];
  bytes = [data mutableBytes];
  for (i = 0; i < 37; i++)
    {
      bytes[i * 2] = words[i] >> 8;
      bytes[i * 2 + 1] = words[i];
    }
  return data;
}
@interface DBNetwork (Private)
- (void) beginConnection;
- (void) lostConnection: (NSString *)reason;
@end
@implementation DBNetwork
- (id) initWithHost: (NSString *)host port: (unsigned int)port
{
  struct addrinfo hints, *result = NULL, *item;
  NSMutableArray *addresses;
  char service[16];
  int error;
  self = [super init];
  if (self == nil)
    return nil;
  _socket = -1;
  if ([host length] == 0 || port == 0 || port > 65535)
    {
      [self release];
      [NSException raise: @"DBNetworkError"
                  format: @"A host and port 1..65535 are required"];
      return nil;
    }
  if ([host isEqual: @"local"] || [host hasPrefix: @"tap:"])
    {
      _host = [host copy];
      _incoming = [NSMutableArray new];
      _outgoing = [NSMutableArray new];
      _input = [NSMutableData new];
      _localServices = [host isEqual: @"local"];
      _tap = !_localServices;
      if (_tap)
        {
          NSString *device = [host substringFromIndex: 4];
#ifdef __linux__
          struct ifreq request;
          memset (&request, 0, sizeof (request));
          request.ifr_flags = IFF_TAP | IFF_NO_PI;
          if ([device length] >= IFNAMSIZ)
            {
              [self release];
              [NSException raise: @"DBNetworkError"
                          format: @"TAP name too long"];
            }
          strncpy (request.ifr_name, [device UTF8String], IFNAMSIZ - 1);
          _socket = open ("/dev/net/tun", O_RDWR | O_NONBLOCK);
          if (_socket >= 0 && ioctl (_socket, TUNSETIFF, &request) < 0)
            {
              close (_socket);
              _socket = -1;
            }
#else
          _socket
              = open ([device fileSystemRepresentation], O_RDWR | O_NONBLOCK);
#endif
          if (_socket < 0)
            {
              [self release];
              [NSException raise: @"DBNetworkError"
                          format: @"Cannot open configured TAP device"];
            }
          fcntl (_socket, F_SETFD, FD_CLOEXEC);
        }
      _status = [_localServices ? @"Local XNS time and echo" : @"Connected TAP"
          copy];
      return self;
    }
  memset (&hints, 0, sizeof (hints));
  hints.ai_socktype = SOCK_STREAM;
  hints.ai_family = AF_UNSPEC;
  snprintf (service, sizeof (service), "%u", port);
  error = getaddrinfo ([host UTF8String], service, &hints, &result);
  if (error != 0)
    {
      [self release];
      [NSException raise: @"DBNetworkError"
                  format: @"Cannot resolve %@: %s", host, gai_strerror (error)];
      return nil;
    }
  addresses = [NSMutableArray array];
  for (item = result; item != NULL; item = item->ai_next)
    if (item->ai_family == AF_INET || item->ai_family == AF_INET6)
      [addresses addObject: [NSData dataWithBytes: item->ai_addr
                                          length: item->ai_addrlen]];
  freeaddrinfo (result);
  if ([addresses count] == 0)
    {
      [self release];
      [NSException raise: @"DBNetworkError"
                  format: @"No TCP address for %@", host];
      return nil;
    }
  _addresses = [addresses copy];
  _host = [host copy];
  _port = port;
  _input = [NSMutableData new];
  _incoming = [NSMutableArray new];
  _outgoing = [NSMutableArray new];
  [self beginConnection];
  return self;
}
- (void) dealloc
{
  [self close];
  [_host release];
  [_status release];
  [_addresses release];
  [_input release];
  [_incoming release];
  [_outgoing release];
  [super dealloc];
}
- (void) close
{
  _closed = YES;
  [self lostConnection: @"Offline"];
}
- (void) lostConnection: (NSString *)reason
{
  if (_socket >= 0)
    close (_socket);
  _socket = -1;
  _connecting = NO;
  _sent = 0;
  [_input setLength: 0];
  [_incoming removeAllObjects];
  [_outgoing removeAllObjects];
  [_status release];
  _status = [reason copy];
  _retryAt = db_net_time () + 2;
}
- (void) beginConnection
{
  NSData *address;
  const struct sockaddr *sa;
  int result;
  if (_closed || [_addresses count] == 0)
    return;
  address = [_addresses objectAtIndex: _addressIndex++ % [_addresses count]];
  sa = [address bytes];
  _socket = socket (sa->sa_family, SOCK_STREAM, 0);
  if (_socket < 0 || fcntl (_socket, F_SETFL, O_NONBLOCK) < 0)
    {
      [self lostConnection: @"Socket unavailable; retrying"];
      return;
    }
  fcntl (_socket, F_SETFD, FD_CLOEXEC);
#ifdef SO_NOSIGPIPE
  {
    int enabled = 1;
    setsockopt (_socket, SOL_SOCKET, SO_NOSIGPIPE, &enabled, sizeof (enabled));
  }
#endif
  result = connect (_socket, sa, (socklen_t)[address length]);
  if (result < 0 && errno != EINPROGRESS)
    {
      [self lostConnection: @"Connection failed; retrying"];
      return;
    }
  _connecting = result < 0;
  _connectUntil = db_net_time () + 5;
  [_status release];
  _status = [[NSString
      stringWithFormat: @"%@ %@:%u", _connecting ? @"Connecting" : @"Connected",
                       _host, _port] copy];
}
- (BOOL) connected
{
  return !_closed && (_localServices || (_socket >= 0 && !_connecting));
}
- (NSString *) status
{
  return _status;
}
- (BOOL) sendPacket: (NSData *)packet
{
  unsigned char header[2];
  NSMutableData *frame;
  NSUInteger length = [packet length];
  if (![self connected] || [_outgoing count] >= 64 || length < 14
      || length > 766)
    return NO;
  if (_localServices)
    {
      NSData *response = db_local_response (packet);
      if (response != nil && [_incoming count] < 64)
        [_incoming addObject: response];
      return YES;
    }
  if (_tap)
    {
      [_outgoing addObject: [[packet copy] autorelease]];
      return YES;
    }
  header[0] = length >> 8;
  header[1] = length;
  frame = [NSMutableData dataWithBytes: header length: 2];
  [frame appendData: packet];
  [_outgoing addObject: frame];
  return YES;
}
- (BOOL) receiveLoopbackPacket: (NSData *)packet
{
  if (_closed || [packet length] < 14 || [packet length] > 766 ||
      [_incoming count] >= 64)
    return NO;
  [_incoming addObject: [[packet copy] autorelease]];
  return YES;
}
- (NSData *) receivePacket
{
  NSData *packet;
  if ([_incoming count] == 0)
    return nil;
  packet = [[[_incoming objectAtIndex: 0] retain] autorelease];
  [_incoming removeObjectAtIndex: 0];
  return packet;
}
- (void) discardReceivedPackets
{
  [_incoming removeAllObjects];
}
- (void) poll
{
  unsigned int work;
  if (_closed)
    return;
  if (_localServices)
    return;
  if (_tap)
    {
      for (work = 0; work < 64; work++)
        {
          unsigned char bytes[2048];
          ssize_t length = read (_socket, bytes, sizeof (bytes));
          if (length < 0
              && (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR))
            break;
          if (length <= 0)
            {
              [self close];
              return;
            }
          if (length >= 14 && length <= 766 && [_incoming count] < 64)
            [_incoming addObject: [NSData dataWithBytes: bytes length: length]];
        }
      for (work = 0; work < 64 && [_outgoing count]; work++)
        {
          NSData *packet = [_outgoing objectAtIndex: 0];
          ssize_t length = write (_socket, [packet bytes], [packet length]);
          if (length < 0
              && (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR))
            break;
          if (length != (ssize_t)[packet length])
            {
              [self close];
              return;
            }
          [_outgoing removeObjectAtIndex: 0];
        }
      return;
    }
  if (_socket < 0)
    {
      if (db_net_time () >= _retryAt)
        [self beginConnection];
      return;
    }
  if (_connecting)
    {
      struct pollfd fd = { _socket, POLLOUT, 0 };
      int result = poll (&fd, 1, 0), error = 0;
      socklen_t size = sizeof (error);
      if (result <= 0)
        {
          if (db_net_time () >= _connectUntil)
            [self lostConnection: @"Connection timed out; retrying"];
          return;
        }
      if (getsockopt (_socket, SOL_SOCKET, SO_ERROR, &error, &size) < 0
          || error != 0)
        {
          [self lostConnection: @"Connection failed; retrying"];
          return;
        }
      _connecting = NO;
      [_status release];
      _status =
          [[NSString stringWithFormat: @"Connected %@:%u", _host, _port] copy];
    }
  for (work = 0; work < 64 && [_outgoing count] != 0; work++)
    {
      NSData *frame = [_outgoing objectAtIndex: 0];
      ssize_t count;
      int flags = 0;
#ifdef MSG_NOSIGNAL
      flags = MSG_NOSIGNAL;
#endif
      count = send (_socket, (const char *) [frame bytes] + _sent,
                    [frame length] - _sent, flags);
      if (count < 0
          && (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR))
        break;
      if (count <= 0)
        {
          [self lostConnection: @"Connection lost; retrying"];
          return;
        }
      _sent += count;
      if (_sent == [frame length])
        {
          [_outgoing removeObjectAtIndex: 0];
          _sent = 0;
        }
    }
  for (work = 0; work < 16; work++)
    {
      unsigned char buffer[1536];
      ssize_t count = recv (_socket, buffer, sizeof (buffer), 0);
      if (count < 0
          && (errno == EAGAIN || errno == EWOULDBLOCK || errno == EINTR))
        break;
      if (count <= 0)
        {
          [self lostConnection: @"Connection lost; retrying"];
          return;
        }
      [_input appendBytes: buffer length: count];
      while ([_input length] >= 2)
        {
          const unsigned char *bytes = [_input bytes];
          unsigned int length = (bytes[0] << 8) | bytes[1];
          if (length < 14 || length > 766)
            {
              [self lostConnection: @"Invalid NetHub frame; retrying"];
              return;
            }
          if ([_input length] < length + 2)
            break;
          if ([_incoming count] < 64)
            [_incoming addObject: [NSData dataWithBytes: bytes + 2
                                                length: length]];
          [_input replaceBytesInRange: NSMakeRange (0, length + 2)
                            withBytes: NULL
                               length: 0];
        }
    }
}
@end
