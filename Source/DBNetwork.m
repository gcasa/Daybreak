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
  return _socket >= 0 && !_connecting;
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
  header[0] = length >> 8;
  header[1] = length;
  frame = [NSMutableData dataWithBytes: header length: 2];
  [frame appendData: packet];
  [_outgoing addObject: frame];
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
