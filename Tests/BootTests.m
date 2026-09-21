/* Optional integration test using user-provided Draco disk images. See
 * COPYING. */
#import "DBMachine.h"
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
int
main (int argc, char **argv)
{
#ifdef GNUSTEP
  extern char **environ;
  GSInitializeProcess (argc, argv, environ);
#endif

  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  DBMachine *volatile machine = nil;
  volatile int result = 1;
  if (argc != 4)
    {
      fprintf (stderr, "Usage: boot-tests DISK EXPECTED_MP SNAPSHOT.pbm\n");
      [pool release];
      return 2;
    }
  NS_DURING
  unsigned int expected = (unsigned int) strtoul (argv[2], NULL, 10);
  double deadline = [NSDate timeIntervalSinceReferenceDate] + 120, readyAt = 0;
  BOOL keyReleased = NO;
  machine =
      [[DBMachine alloc] initWithDisk: [NSString stringWithUTF8String: argv[1]]
                             switches: nil];
  while ([NSDate timeIntervalSinceReferenceDate] < deadline
         && ![machine halted])
    {
      double now;
      NSAutoreleasePool *slice = [NSAutoreleasePool new];
      [machine runForInstructions: 50000];
      [slice release];
      now = [NSDate timeIntervalSinceReferenceDate];
      if (readyAt == 0 && [machine state]->MP == expected &&
          [machine displayEnabled] && [machine diskReads] >= 19000)
        {
          readyAt = now;
          if (expected == 8000)
            [machine setKey: 73 pressed: YES];
        }
      if (readyAt != 0 && now - readyAt > 0.15 && !keyReleased)
        {
          [machine releaseKeys];
          keyReleased = YES;
        }
      if (readyAt != 0 && now - readyAt > 2)
        break;
      if (![machine state]->running)
        {
          struct timespec delay = { 0, 1000000 };
          nanosleep (&delay, NULL);
        }
    }
  {
    NSData *screen = [machine displayData];
    const unsigned char *bytes = [screen bytes];
    NSUInteger i, dark = 0, light = 0;
    NSMutableData *pbm = [NSMutableData dataWithBytes: "P4\n832 633\n"
                                               length: 11];
    for (i = 0; i < [screen length]; i++)
      {
        if (bytes[i] != 0)
          dark++;
        if (bytes[i] != 255)
          light++;
      }
    [pbm appendData: screen];
    if (![pbm writeToFile: [NSString stringWithUTF8String: argv[3]]
               atomically: YES])
      [NSException raise: @"DBTestFailure" format: @"Cannot save boot evidence"];
    result = readyAt != 0 && [machine diskReads] > 1000 && dark > 100
                     && light > 100
                 ? 0
                 : 1;
    printf ("%s: MP=%u instructions=%llu reads=%llu writes=%llu "
            "framebuffer=%lu/%lu %s\n",
            argv[1], [machine state]->MP,
            (unsigned long long) [machine state]->instructions,
            (unsigned long long) [machine diskReads],
            (unsigned long long) [machine diskWrites], (unsigned long) dark,
            (unsigned long) light, result ? "FAILED" : "PASSED");
  }
  NS_HANDLER
  fprintf (stderr, "%s: %s\n", [[localException name] UTF8String],
           [[localException reason] UTF8String]);
  result = 1;
  NS_ENDHANDLER
  [machine release];
  [pool release];
  return result;
}
