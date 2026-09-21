/** <title>NetHub Ethernet transport</title>
    <author name="Daybreak contributors"></author>
    Derived from Dwarf by Dr. Hans-Walter Latz. See COPYING. */
#ifndef DAYBREAK_NETWORK_H
#define DAYBREAK_NETWORK_H
#import <Foundation/Foundation.h>
/** Single-threaded, nonblocking TCP transport for Dwarf NetHub. Frames have a
    two-byte big-endian length followed by 14..766 Ethernet bytes. Queues are
    bounded to 64 packets. Poll on the owning emulator thread; no worker thread
    accesses Mesa memory. DNS lookup occurs once during initialization. */
@interface DBNetwork : NSObject
{
  NSString *_host, *_status;
  unsigned int _port, _addressIndex;
  NSArray *_addresses;
  int _socket;
  BOOL _connecting, _closed;
  double _retryAt, _connectUntil;
  NSMutableData *_input;
  NSMutableArray *_incoming, *_outgoing;
  NSUInteger _sent;
}
/** Resolve host and start connecting. Invalid endpoints raise DBNetworkError.
    Connection failures are reported by status and retried every two seconds.
 */
- (id) initWithHost: (NSString *)host port: (unsigned int)port;
/** Service bounded nonblocking reads/writes and connection progress. */
- (void) poll;
/** Queue an Ethernet frame. Return NO when disconnected, full or malformed.
    YES means queued locally, not acknowledged by the remote guest. */
- (BOOL) sendPacket: (NSData *)packet;
/** Return an autoreleased received frame, or nil if none is waiting. */
- (NSData *) receivePacket;
/** Drop buffered input packets without interrupting TCP framing. */
- (void) discardReceivedPackets;
/** Close permanently, dropping pending packets. Safe to call repeatedly. */
- (void) close;
/** Return YES once the TCP connection is established. */
- (BOOL) connected;
/** Return a borrowed human-readable connection status. */
- (NSString *) status;
@end
#endif
