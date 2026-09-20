/* Daybreak Mesa instruction runner.  See COPYING. */
#import "DBProcessor.h"
#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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
      "       daybreak --help\n\n"
      "Execute a big-endian Mesa instruction image in identity-mapped RAM.\n"
      "Defaults: 100 instructions, PC 0, word base 0x30000, PrincOps 4.0.\n"
      "This is an instruction runner; workstation OS boot is not "
      "implemented.\n");
}

int
main (int argc, char **argv)
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  DBMemory *volatile memory = nil;
  DBProcessor *volatile cpu = nil;
  NSData *data = nil;
  const char *file = NULL;
  uint32_t steps = 100, pc = 0, base = 0x30000;
  BOOL post40 = NO, demo = NO;
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
      else if (strcmp (argv[i], "--post40") == 0)
        post40 = YES;
      else if (strcmp (argv[i], "--steps") == 0
               || strcmp (argv[i], "--pc") == 0
               || strcmp (argv[i], "--base") == 0)
        {
          const char *option = argv[i];
          uint32_t *value = strcmp (option, "--steps") == 0 ? &steps
                            : strcmp (option, "--pc") == 0  ? &pc
                                                            : &base;
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
  if (status || (demo && file != NULL) || (!demo && file == NULL))
    {
      db_usage (stderr);
      [pool release];
      return 2;
    }
  NS_DURING
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
      data =
          [NSData dataWithContentsOfFile: [NSString stringWithUTF8String: file]];
      if (data == nil)
        [NSException raise: @"DBInputError" format: @"Cannot read %s", file];
    }
  memory = [[DBMemory alloc] initWithRealPages: 8192 virtualPages: 65536];
  [memory loadData: data atRealAddress: base];
  cpu = [[DBProcessor alloc] initWithMemory: memory post40: post40];
  [cpu state]->CB = base;
  [cpu state]->PC = pc;
  [cpu runForInstructions: steps];
  printf ("instructions=%llu PC=%04x SP=%u stack:",
          (unsigned long long) [cpu state]->instructions, [cpu state]->PC,
          [cpu state]->SP);
  for (i = 0; i < (int) [cpu state]->SP; i++)
    printf (" %04x", [cpu state]->stack[i]);
  printf ("\n");
  NS_HANDLER
  fprintf (stderr, "%s: %s\n", [[localException name] UTF8String],
           [[localException reason] UTF8String]);
  status = 1;
  NS_ENDHANDLER
  [cpu release];
  [memory release];
  [pool release];
  return status;
}
