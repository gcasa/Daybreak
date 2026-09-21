/* SCP container layout: SuperCard Pro specification v2.5,
   copyright (C) 2012-2022 Jim Drew; permission granted for inclusion with
   source code retaining this notice.
   https://www.cbmstuff.com/downloads/scp/scp_image_specs.txt Native MFM sector
   decoder for Daybreak. See COPYING. */
#import "DBFloppy.h"
#include <stdint.h>
#include <string.h>

@interface DBFloppy (Flux)
- (void) loadSCP: (NSData *)data;
@end
@interface DBFloppy (SectorBuilder)
- (void) addCylinder: (unsigned int)c
               head: (unsigned int)h
             sector: (unsigned int)s
               data: (NSData *)data
               kind: (unsigned int)kind
               mode: (unsigned int)mode;
@end
static uint32_t
flux_le32 (const unsigned char *p)
{
  return p[0] | ((uint32_t) p[1] << 8) | ((uint32_t) p[2] << 16)
         | ((uint32_t) p[3] << 24);
}
static void
flux_error (void)
{
  [NSException raise: @"DBFloppyError"
              format: @"Invalid or unsupported SCP MFM image"];
}
static uint16_t
flux_crc (uint16_t crc, unsigned char byte)
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
static uint16_t
flux_word (const unsigned char *bits, NSUInteger at)
{
  unsigned int i;
  uint16_t word = 0;
  for (i = 0; i < 16; i++)
    word = (word << 1) | bits[at + i];
  return word;
}
static unsigned char
flux_byte (const unsigned char *bits, NSUInteger at)
{
  unsigned int i;
  unsigned char byte = 0;
  for (i = 1; i < 16; i += 2)
    byte = (byte << 1) | bits[at + i];
  return byte;
}
@implementation DBFloppy (Flux)
- (void) loadSCP: (NSData *)data
{
  const unsigned char *p = [data bytes];
  NSUInteger length = [data length], j;
  unsigned int track, rev, revolutions;
  uint32_t checksum = 0;
  if (length < 688 || memcmp (p, "SCP", 3) || !p[5] || p[5] > 16 || p[6] > p[7]
      || p[7] >= 168 || p[9] || (p[8] & 0x40))
    flux_error ();
  for (j = 16; j < length; j++)
    checksum += p[j];
  if (!(p[8] & 16) && checksum != flux_le32 (p + 12))
    flux_error ();
  _readOnly |= !(p[8] & 16);
  revolutions = p[5];
  for (track = p[6]; track <= p[7]; track++)
    {
      uint32_t base = flux_le32 (p + 16 + track * 4);
      if (base == 0)
        continue;
      if (base < 688 || (uint64_t) base + 4 + revolutions * 12 > length
          || memcmp (p + base, "TRK", 3) || p[base + 3] != track)
        flux_error ();
      for (rev = 0; rev < revolutions; rev++)
        {
          NSAutoreleasePool *pool = [NSAutoreleasePool new];
          uint32_t count = flux_le32 (p + base + 8 + rev * 12);
          uint32_t offset = flux_le32 (p + base + 12 + rev * 12);
          unsigned int cell = 40, candidate, best = UINT32_MAX;
          const unsigned char *samples;
          NSMutableData *stream = [NSMutableData data];
          unsigned int pending = 0, c = 0, h = 0, sectorID = 0, size = 0;
          BOOL headerBad = NO;
          uint32_t overflow = 0;
          const unsigned char *bits;
          NSUInteger original, at;
          if (count > 1000000 || offset < 4 + revolutions * 12
              || (uint64_t) base + offset + (uint64_t) count * 2 > length)
            flux_error ();
          samples = p + base + offset;
          /* Select the standard MFM bit-cell rate with the smallest timing
             residual, penalizing intervals outside the legal 2..4 cells. */
          for (candidate = 20; candidate <= 160; candidate *= 2)
            {
              unsigned int score = 0;
              for (j = 0; j < MIN (count, 8192U); j++)
                {
                  unsigned int ticks
                      = ((samples[j * 2] << 8) | samples[j * 2 + 1])
                        * (p[11] + 1);
                  unsigned int n = (ticks + candidate / 2) / candidate;
                  if (n < 2 || n > 4)
                    score += 100;
                  else
                    score += abs ((int) ticks - (int) (n * candidate)) * 100
                             / candidate;
                }
              if (score < best)
                {
                  best = score;
                  cell = candidate;
                }
            }
          for (j = 0; j < count; j++)
            {
              unsigned int ticks = (samples[j * 2] << 8) | samples[j * 2 + 1];
              NSUInteger old = [stream length];
              unsigned int n;
              if (!ticks)
                {
                  overflow += 65536;
                  if (overflow > 40000000)
                    flux_error ();
                  continue;
                }
              n = (((uint64_t) ticks + overflow) * (p[11] + 1) + cell / 2)
                  / cell;
              overflow = 0;
              if (n == 0)
                n = 1;
              if (n > 1000000 || old + n > 2000000)
                flux_error ();
              [stream increaseLengthBy: n];
              ((unsigned char *) [stream mutableBytes])[old + n - 1] = 1;
            }
          original = [stream length];
          if (original < 160)
            {
              [pool release];
              continue;
            }
          [stream appendData: [[stream copy] autorelease]];
          bits = [stream bytes];
          for (at = 0; at + 160 < [stream length] && at < original + 140000;
               at++)
            if (flux_word (bits, at) == 0x4489
                && flux_word (bits, at + 16) == 0x4489
                && flux_word (bits, at + 32) == 0x4489)
              {
                unsigned int mark = flux_byte (bits, at + 48), i;
                uint16_t crc = flux_crc (0xcdb4, mark);
                if (mark == 0xfe)
                  {
                    unsigned int code;
                    c = flux_byte (bits, at + 64);
                    h = flux_byte (bits, at + 80);
                    sectorID = flux_byte (bits, at + 96);
                    code = flux_byte (bits, at + 112);
                    pending = c < 85 && h < 2 && sectorID > 0 && code <= 6;
                    size = pending ? 128U << code : 0;
                    for (i = 0; i < 6; i++)
                      crc = flux_crc (crc, flux_byte (bits, at + 64 + i * 16));
                    headerBad = crc != 0;
                    at += 159;
                  }
                else if (pending && (mark == 0xfb || mark == 0xf8)
                         && at + 64 + (size + 2) * 16 <= [stream length])
                  {
                    NSMutableData *sector =
                        [NSMutableData dataWithLength: size];
                    unsigned char *bytes = [sector mutableBytes];
                    NSNumber *key = [NSNumber
                        numberWithUnsignedInt: (c << 16) | (h << 8) | sectorID];
                    unsigned int kind;
                    for (i = 0; i < size + 2; i++)
                      {
                        unsigned char byte
                            = flux_byte (bits, at + 64 + i * 16);
                        if (i < size)
                          bytes[i] = byte;
                        crc = flux_crc (crc, byte);
                      }
                    kind = (headerBad || crc ? 4 : 0) + (mark == 0xf8 ? 3 : 1);
                    if ([_sectors objectForKey: key] == nil
                        || ([[_kinds objectForKey: key] unsignedIntValue] >= 5
                            && kind < 5))
                      {
                        [_sectors removeObjectForKey: key];
                        [self addCylinder: c
                                     head: h
                                   sector: sectorID
                                     data: sector
                                     kind: kind
                                     mode: 5];
                      }
                    at += 63 + (size + 2) * 16;
                    pending = 0;
                  }
              }
          [pool release];
        }
    }
}
@end
