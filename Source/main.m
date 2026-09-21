/* Daybreak Mesa instruction runner.  See COPYING. */
#import "DBProcessor.h"
#import "DBMachine.h"
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static BOOL
db_number (const char *text, uint32_t maximum, uint32_t *result)
{
  char *end;
  unsigned long value;
  if (*text == '-' || *text == '\0')
    return NO;
  errno = 0;
  value = strtoul (text, &end, 0);
  if (errno != 0 || *end != '\0' || value > maximum)
    return NO;
  *result = (uint32_t) value;
  return YES;
}

static void
db_usage (FILE *stream)
{
  fprintf (
      stream,
      "Usage: daybreak --demo\n"
      "       daybreak [--post40] [--steps N] [--pc N] [--base N] FILE\n"
      "       daybreak --disk [--seconds N | --steps N] [--snapshot "
      "FILE.pbm]\n"
      "                [--save-copy FILE.zdisk] [--switches STRING] "
      "DISK.zdisk\n"
      "                [--floppy FILE.imd|FILE.dmk] [--floppy-read-only]\n"
      "                [--save-floppy COPY.imd] [--hub HOST] [--hub-port "
      "PORT]\n"
      "                [--host-id 1000FE31AB21]\n\n"
      "Disk mode loads the embedded Draco germ and boots for 30 seconds.\n"
      "Disk changes stay in memory unless --save-copy is specified.\n"
      "Raw mode defaults to 100 instructions, PC 0, word base 0x30000.\n");
}

int
main (int argc, char **argv)
{
#ifdef GNUSTEP
  extern char **environ;
  GSInitializeProcess (argc, argv, environ);
#endif

  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  DBMemory *volatile memory = nil;
  DBProcessor *volatile cpu = nil;
  NSData *data = nil;
  const char *file = NULL, *snapshot = NULL, *saveCopy = NULL,
             *switches = NULL, *floppy = NULL, *floppyCopy = NULL, *hub = NULL,
             *hostID = NULL;
  BOOL floppyReadOnly = NO, explicitHubPort = NO;
  uint32_t hubPort = 3333;
  uint32_t steps = 100, pc = 0, base = 0x30000, seconds = 30;
  BOOL explicitSteps = NO, explicitSeconds = NO;
  BOOL post40 = NO, demo = NO, disk = NO;
  int i, status = 0;
  for (i = 1; i < argc; i++)
    {
      if (strcmp (argv[i], "--help") == 0)
        {
          db_usage (stdout);
          [pool release];
          return 0;
        }
      else if (strcmp (argv[i], "--demo") == 0)
        demo = YES;
      else if (strcmp (argv[i], "--disk") == 0)
        disk = YES;
      else if (strcmp (argv[i], "--floppy-read-only") == 0)
        floppyReadOnly = YES;
      else if (strcmp (argv[i], "--hub-port") == 0)
        {
          explicitHubPort = YES;
          if (++i >= argc || !db_number (argv[i], 65535, &hubPort)
              || hubPort == 0)
            {
              status = 2;
              break;
            }
        }
      else if (strcmp (argv[i], "--post40") == 0)
        post40 = YES;
      else if (strcmp (argv[i], "--snapshot") == 0
               || strcmp (argv[i], "--save-copy") == 0
               || strcmp (argv[i], "--switches") == 0
               || strcmp (argv[i], "--floppy") == 0
               || strcmp (argv[i], "--save-floppy") == 0
               || strcmp (argv[i], "--hub") == 0
               || strcmp (argv[i], "--host-id") == 0)
        {
          const char *option = argv[i];
          if (++i >= argc)
            {
              status = 2;
              break;
            }
          if (strcmp (option, "--snapshot") == 0)
            snapshot = argv[i];
          else if (strcmp (option, "--save-copy") == 0)
            saveCopy = argv[i];
          else if (strcmp (option, "--switches") == 0)
            switches = argv[i];
          else if (strcmp (option, "--floppy") == 0)
            floppy = argv[i];
          else if (strcmp (option, "--save-floppy") == 0)
            floppyCopy = argv[i];
          else if (strcmp (option, "--hub") == 0)
            hub = argv[i];
          else
            hostID = argv[i];
        }
      else if (strcmp (argv[i], "--seconds") == 0)
        {
          explicitSeconds = YES;
          if (++i >= argc || !db_number (argv[i], 86400, &seconds))
            {
              status = 2;
              break;
            }
        }
      else if (strcmp (argv[i], "--steps") == 0
               || strcmp (argv[i], "--pc") == 0
               || strcmp (argv[i], "--base") == 0)
        {
          const char *option = argv[i];
          uint32_t *value = strcmp (option, "--steps") == 0 ? &steps
                            : strcmp (option, "--pc") == 0  ? &pc
                                                            : &base;
          if (value == &steps)
            explicitSteps = YES;
          uint32_t limit = value == &steps ? 0xffffffffU
                           : value == &pc  ? 65535
                                           : 0x1fffff;
          if (++i >= argc || !db_number (argv[i], limit, value))
            {
              fprintf (stderr, "Invalid value for %s\n", option);
              status = 2;
              break;
            }
        }
      else if (argv[i][0] == '-' || file != NULL)
        {
          status = 2;
          break;
        }
      else
        file = argv[i];
    }
  if (status || (demo && (disk || file != NULL)) || (!demo && file == NULL)
      || (explicitSteps && explicitSeconds) || (floppyCopy && !floppy)
      || (floppyReadOnly && !floppy) || (explicitHubPort && !hub)
      || (!disk
          && (snapshot || saveCopy || switches || explicitSeconds || floppy
              || hub || hostID)))
    {
      db_usage (stderr);
      [pool release];
      return 2;
    }
  NS_DURING
  if (disk)
    {
      cpu = [[DBMachine alloc]
          initWithDisk: [NSString stringWithUTF8String: file]
              switches: switches ? [NSString stringWithUTF8String: switches]
                                : nil];
      if (hostID)
        [(DBMachine *) cpu setHostID: [NSString stringWithUTF8String: hostID]];
      if (floppy)
        [(DBMachine *) cpu insertFloppy: [NSString stringWithUTF8String: floppy]
                               readOnly: floppyReadOnly];
      if (hub)
        [(DBMachine *) cpu setNetworkHost: [NSString stringWithUTF8String: hub]
                                     port: hubPort];
      if (explicitSteps)
        [cpu runForInstructions: steps];
      else
        {
          double end = [NSDate timeIntervalSinceReferenceDate] + seconds;
          while ([NSDate timeIntervalSinceReferenceDate] < end
                 && ![(DBMachine *) cpu halted])
            {
              NSAutoreleasePool *slice = [NSAutoreleasePool new];
              NS_DURING
              [cpu runForInstructions: 50000];
              NS_HANDLER
              [localException retain];
              [slice release];
              [[localException autorelease] raise];
              NS_ENDHANDLER
              [slice release];
              if (![cpu state]->running)
                {
                  struct timespec pause = { 0, 1000000 };
                  nanosleep (&pause, NULL);
                }
            }
        }
      if (snapshot != NULL)
        {
          NSMutableData *image = [NSMutableData dataWithBytes: "P4\n832 633\n"
                                                       length: 11];
          [image appendData: [(DBMachine *) cpu displayData]];
          if (![image writeToFile: [NSString stringWithUTF8String: snapshot]
                       atomically: YES])
            [NSException raise: @"DBOutputError"
                        format: @"Cannot write framebuffer"];
        }
      if (floppyCopy)
        [[(DBMachine *) cpu floppy]
            saveCopyToPath: [NSString stringWithUTF8String: floppyCopy]];
      if (hub)
        printf ("Network: %s sent=%llu received=%llu\n",
                [[[(DBMachine *) cpu network] status] UTF8String],
                (unsigned long long) [(DBMachine *) cpu packetsSent],
                (unsigned long long) [(DBMachine *) cpu packetsReceived]);
      if (saveCopy != NULL)
        [[(DBMachine *) cpu disk]
            saveCopyToPath: [NSString stringWithUTF8String: saveCopy]];
      printf ("MP=%u diskReads=%llu\n", [cpu state]->MP,
              (unsigned long long) [(DBMachine *) cpu diskReads]);
    }
  else
    {
      if (demo)
        {
          /* LIB 7; LIB 6; MUL; LI1; ADD; J2 (word-aligned image). */
          const unsigned char program[]
              = { 0xcd, 7, 0xcd, 6, 0xbc, 0xc1, 0xb5, 0x81 };
          data = [NSData dataWithBytes: program length: sizeof (program)];
          steps = 5;
          pc = 0;
        }
      else
        {
          data = [NSData
              dataWithContentsOfFile: [NSString stringWithUTF8String: file]];
          if (data == nil)
            [NSException raise: @"DBInputError" format: @"Cannot read %s", file];
        }
      memory = [[DBMemory alloc] initWithRealPages: 8192 virtualPages: 65536];
      [memory loadData: data atRealAddress: base];
      cpu = [[DBProcessor alloc] initWithMemory: memory post40: post40];
      [cpu state]->CB = base;
      [cpu state]->PC = pc;
      [cpu runForInstructions: steps];
    }
  printf ("instructions=%llu PC=%04x SP=%u stack:",
          (unsigned long long) [cpu state]->instructions, [cpu state]->PC,
          [cpu state]->SP);
  for (i = 0; i < (int) [cpu state]->SP; i++)
    printf (" %04x", [cpu state]->stack[i]);
  printf ("\n");
  NS_HANDLER
  fprintf (stderr, "%s: %s\n", [[localException name] UTF8String],
           [[localException reason] UTF8String]);
  if (cpu != nil)
    fprintf (stderr, "MP=%u instructions=%llu CB=%08x PC=%04x LF=%04x SP=%u\n",
             [cpu state]->MP, (unsigned long long) [cpu state]->instructions,
             [cpu state]->CB, [cpu state]->PC, [cpu state]->LF,
             [cpu state]->SP);
  status = 1;
  NS_ENDHANDLER
  [cpu release];
  [memory release];
  [pool release];
  return status;
}
