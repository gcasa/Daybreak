/* Daybreak regression tests.  See COPYING. */
#import "DBProcessor.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

static unsigned int checks;
#define CHECK(condition)                                                      \
  do                                                                          \
    {                                                                         \
      checks++;                                                               \
      if (!(condition))                                                       \
        {                                                                     \
          fprintf (stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__,            \
                   #condition);                                               \
          exit (1);                                                           \
        }                                                                     \
    }                                                                         \
  while (0)
#define EXPECT_EXCEPTION(statement, expected)                                 \
  do                                                                          \
    {                                                                         \
      volatile BOOL caught = NO;                                              \
      NS_DURING statement;                                                    \
      NS_HANDLER                                                              \
      CHECK ([[localException name] isEqualToString: expected]);               \
      caught = YES;                                                           \
      NS_ENDHANDLER CHECK (caught);                                           \
    }                                                                         \
  while (0)

static void
put_code (DBProcessor *cpu, unsigned int opcode, BOOL escape,
          unsigned int byte1, unsigned int byte2)
{
  DBProcessorState *state = [cpu state];
  DBMemory *memory = [cpu memory];
  [cpu reset];
  state->CB = 0x30000;
  [memory writeWord: state->CB
              value: escape ? 0xf800 | opcode : (opcode << 8) | byte1];
  [memory writeWord: state->CB + 1
              value: escape ? (byte1 << 8) | byte2 : byte2 << 8];
}

static void
memory_tests (void)
{
  DBMemory *memory = [[DBMemory alloc] initWithRealPages: 2 virtualPages: 4];
  const unsigned char image[] = { 0x12, 0x34, 0xab, 0xcd };
  unsigned int pos, width;
  [memory loadData: [NSData dataWithBytes: image length: 4] atRealAddress: 0];
  [memory mapPage: 1 to: 0 flags: 0];
  CHECK ([memory readWord: 256] == 0x1234);
  CHECK ([memory readDoubleWord: 256] == 0xabcd1234U);
  CHECK ([memory fetchByte: 256 offset: 0] == 0x12);
  CHECK ([memory fetchByte: 256 offset: 1] == 0x34);
  CHECK ([memory flagsForPage: 1] == DB_MAP_REFERENCED);
  [memory storeByte: 256 offset: 0 value: 0x98];
  CHECK ([memory readWord: 256] == 0x9834);
  [memory storeByte: 256 offset: 1 value: 0x76];
  CHECK ([memory readWord: 256] == 0x9876);
  CHECK ([memory flagsForPage: 1] == 3);
  [memory mapPage: 3 to: 0 flags: 0];
  CHECK ([memory readWord: 768] == 0x9876);
  [memory mapPage: 3 to: 1 flags: DB_MAP_PROTECTED];
  EXPECT_EXCEPTION ([memory writeWord: 768 value: 1], @"DBWriteProtectFault");
  CHECK ([memory flagsForPage: 3] == DB_MAP_PROTECTED);
  EXPECT_EXCEPTION ([memory readWord: 512], @"DBPageFault");
  EXPECT_EXCEPTION ([memory readWord: 0xffffffffU], @"DBPointerTrap");
  [memory mapPage: 3 to: 0xffffffffU flags: DB_MAP_VACANT];
  CHECK ([memory realPageForPage: 3] == 0);
  EXPECT_EXCEPTION ([memory mapPage: 0 to: 2 flags: 0],
                    NSInvalidArgumentException);
  EXPECT_EXCEPTION ([memory loadData: [NSData dataWithBytes: image length: 3]
                        atRealAddress: 0],
                    NSInvalidArgumentException);
  CHECK ([memory readWord: 256] == 0x9876);
  EXPECT_EXCEPTION ([memory loadData: [NSData dataWithBytes: image length: 4]
                        atRealAddress: 511],
                    NSInvalidArgumentException);
  for (pos = 0; pos < 16; pos++)
    for (width = 1; width + pos <= 16; width++)
      {
        uint8_t spec = (pos << 4) | (width - 1);
        uint16_t mask = ((1UL << width) - 1) << (16 - pos - width);
        uint16_t word = [DBMemory word: 0xa55a
                         specification: spec
                             withField: 0xffff];
        CHECK (word == (uint16_t) (0xa55a | mask));
        CHECK ([DBMemory fieldFromWord: word specification: spec]
               == ((1UL << width) - 1));
      }
  EXPECT_EXCEPTION ([DBMemory fieldFromWord: 0 specification: 0xff],
                    NSInvalidArgumentException);
  [memory release];
}

static void
processor_tests (void)
{
  DBMemory *memory = [[DBMemory alloc] initWithRealPages: 1024
                                            virtualPages: 2048];
  DBProcessor *cpu = [[DBProcessor alloc] initWithMemory: memory post40: NO];
  DBProcessor *modern = [[DBProcessor alloc] initWithMemory: memory post40: YES];
  DBProcessorState *s = [cpu state];
  unsigned int i;
  for (i = 0; i < DB_STACK_LENGTH; i++)
    [cpu push: i];
  EXPECT_EXCEPTION ([cpu push: 99], @"DBStackError");
  CHECK (s->SP == DB_STACK_LENGTH);
  CHECK ([cpu pop] == 13);
  EXPECT_EXCEPTION ([cpu pushLong: 99], @"DBStackError");
  CHECK (s->SP == 13);
  [cpu reset];
  EXPECT_EXCEPTION ([cpu pop], @"DBStackError");
  [cpu push: 0xabcd];
  EXPECT_EXCEPTION ([cpu popLong], @"DBStackError");
  CHECK (s->SP == 1);
  [cpu pushLong: 0x87654321];
  CHECK (s->stack[1] == 0x4321 && s->stack[2] == 0x8765);
  CHECK ((uint32_t) [cpu popLong] == 0x87654321U);
  [cpu discard];
  [cpu recover];
  CHECK ((uint16_t) [cpu pop] == 0xabcd);

  put_code (cpu, 0xb5, NO, 0, 0);
  [cpu push: 0xffff];
  [cpu push: 1];
  [cpu step];
  CHECK ([cpu pop] == 0 && s->instructions == 1);
  put_code (cpu, 0xbc, NO, 0, 0);
  [cpu push: 0xffff];
  [cpu push: 0xffff];
  [cpu step];
  CHECK ([cpu pop] == 1);
  [cpu recover];
  [cpu recover];
  CHECK ((uint16_t) [cpu pop] == 0xfffe);
  put_code (cpu, 0x32, YES, 0, 0);
  [cpu pushLong: 0x80000000];
  [cpu pushLong: 0xffffffff];
  [cpu step];
  CHECK ((uint32_t) [cpu popLong] == 0x80000000U);
  put_code (cpu, 0x1d, YES, 0, 0);
  [cpu pushLong: 0x10000];
  [cpu push: 1];
  EXPECT_EXCEPTION ([cpu step], @"DBDivideCheckTrap");
  CHECK (s->SP == 3 && s->PC == 0 && s->instructions == 0);
  put_code (cpu, 0x1c, YES, 0, 0);
  [cpu push: 42];
  [cpu push: 0];
  EXPECT_EXCEPTION ([cpu step], @"DBDivideZeroTrap");
  CHECK (s->SP == 2 && s->stack[0] == 42 && s->PC == 0);
  s->stack[1] = 7;
  [cpu step];
  CHECK ([cpu pop] == 6);
  for (i = 0; i < 2; i++)
    {
      put_code (cpu, 0x7b, NO, 0, 0);
      [cpu push: 0xffff];
      [cpu push: i ? 32767 : 0x8000];
      [cpu step];
      CHECK ([cpu pop] == 0);
    }
  put_code (cpu, 0x16, YES, 0, 0);
  [cpu push: 0x8001];
  [cpu push: 1];
  [cpu step];
  CHECK ([cpu pop] == 3);
  put_code (cpu, 0x88, NO, 0xfe, 0);
  [cpu step];
  CHECK (s->PC == 65534);
  put_code (cpu, 0x90, NO, 5, 0);
  [cpu push: 0xffff];
  [cpu push: 0];
  [cpu step];
  CHECK (s->PC == 5);
  put_code (cpu, 0x94, NO, 5, 0);
  [cpu push: 0xffff];
  [cpu push: 0];
  [cpu step];
  CHECK (s->PC == 2);
  put_code (cpu, 0xcd, NO, 0, 0);
  s->PC = 65535;
  [memory writeWord: s->CB + 32767 value: 0x00cd];
  [memory writeWord: s->CB value: 0x7f00];
  [cpu step];
  CHECK (s->PC == 1 && [cpu pop] == 127);
  put_code (cpu, 0x0d, NO, 1, 0);
  s->MDS = 0x10000;
  s->LF = 65535;
  [memory writeWord: 0x10000 value: 0xbeef];
  [cpu step];
  CHECK ((uint16_t) [cpu pop] == 0xbeef);
  put_code (cpu, 0x34, NO, 0, 0);
  s->GF16 = 0x2000;
  s->MDS = 0x10000;
  [memory writeWord: 0x12000 value: 0x1234];
  [cpu step];
  CHECK ([cpu pop] == 0x1234);
  put_code (modern, 0x34, NO, 0, 0);
  [modern state]->GF32 = 0x12000;
  [modern step];
  CHECK ([modern pop] == 0x1234);
  CHECK (![cpu supportsOpcode: 0xfa escape: NO]);
  CHECK ([modern supportsOpcode: 0xfa escape: NO]);
  CHECK ([modern state]->instructions == 1);

  put_code (cpu, 0x40, NO, 0, 0);
  s->MDS = 0x40000;
  [cpu push: 12];
  EXPECT_EXCEPTION ([cpu step], @"DBPageFault");
  CHECK (s->PC == 0 && s->SP == 1 && s->stack[0] == 12);
  [memory mapPage: 1024 to: 2 flags: 0];
  [memory writeWord: 524 value: 0x4321];
  [cpu step];
  CHECK ([cpu pop] == 0x4321);
  put_code (cpu, 0, NO, 0, 0);
  EXPECT_EXCEPTION ([cpu step], @"DBOpcodeTrap");
  CHECK (s->PC == 0);
  put_code (cpu, 0, YES, 0, 0);
  EXPECT_EXCEPTION ([cpu step], @"DBEscapeOpcodeTrap");
  CHECK (s->PC == 0);
  put_code (cpu, 0x07, YES, 0, 0);
  [cpu pushLong: 1200];
  [cpu pushLong: 3];
  [cpu push: 0];
  [cpu step];
  CHECK ([memory realPageForPage: 1200] == 3);
  put_code (cpu, 0x09, YES, 0, 0);
  [cpu pushLong: 1200];
  [cpu step];
  CHECK ([cpu popLong] == 3 && [cpu pop] == 0);
  put_code (cpu, 0x08, YES, 0, 0);
  [cpu pushLong: 1200];
  [cpu push: DB_MAP_PROTECTED];
  [cpu step];
  CHECK ([cpu popLong] == 3 && [cpu pop] == 0);
  CHECK ([memory flagsForPage: 1200] == DB_MAP_PROTECTED);
  put_code (cpu, 0x71, YES, 0, 0);
  [cpu push: 0x8000];
  [cpu step];
  CHECK (s->MDS == 0x80000000U);
  put_code (cpu, 0xf7, NO, 0, 0);
  s->MDS = 0x10000;
  [cpu push: 0];
  [cpu step];
  CHECK ([cpu popLong] == 0);
  put_code (cpu, 0xf7, NO, 0, 0);
  s->MDS = 0x10000;
  [cpu push: 0xffff];
  [cpu step];
  CHECK ([cpu popLong] == 0x1ffff);
  put_code (cpu, 0x1e, YES, 2, 0);
  s->MDS = 0x10000;
  [memory writeWord: 0x100fe value: 0x7654];
  [cpu push: 0x100];
  [cpu step];
  CHECK ([cpu pop] == 0x7654);
  put_code (cpu, 0x6c, NO, 0x43, 0);
  [memory writeWord: 0x2000 value: 0xabcd];
  [cpu push: 5];
  [cpu push: 0x2000];
  [cpu step];
  CHECK ([memory readWord: 0x2000] == 0xa5cd);
  CHECK (s->SP == 0);
  put_code (cpu, 0x63, NO, 1, 0);
  [memory writeWord: 0x2000 value: 0xabcd];
  [cpu push: 0xef];
  [cpu push: 0x2000];
  [cpu push: 0];
  [cpu step];
  CHECK ([memory readWord: 0x2000] == 0xabef);
  [modern release];
  [cpu release];
  [memory release];
}

/* Read independently generated, successful Dwarf instruction executions. */
static void
reference_tests (const char *path)
{
  FILE *file = fopen (path, "r");
  DBMemory *memory = [[DBMemory alloc] initWithRealPages: 1024
                                            virtualPages: 1024];
  DBProcessor *cpu = [[DBProcessor alloc] initWithMemory: memory post40: NO];
  unsigned int opcode, escape, byte1, byte2, beforeSP, afterSP, afterPC;
  unsigned int before[14], after[14], i, row = 0;
  CHECK (file != NULL);
  while (fscanf (file, "%u %u %u %u %u", &opcode, &escape, &byte1, &byte2,
                 &beforeSP)
         == 5)
    {
      for (i = 0; i < 14; i++)
        CHECK (fscanf (file, "%u", &before[i]) == 1);
      CHECK (fscanf (file, "%u %u", &afterPC, &afterSP) == 2);
      for (i = 0; i < 14; i++)
        CHECK (fscanf (file, "%u", &after[i]) == 1);
      put_code (cpu, opcode, escape, byte1, byte2);
      [cpu state]->SP = beforeSP;
      for (i = 0; i < 14; i++)
        [cpu state]->stack[i] = before[i];
      [cpu step];
      if ([cpu state]->PC != afterPC || [cpu state]->SP != afterSP)
        {
          fprintf (stderr, "Reference row %u opcode %02x PC/SP mismatch\n",
                   row, opcode);
          exit (1);
        }
      for (i = 0; i < 14; i++)
        {
          if ([cpu state]->stack[i] != after[i])
            {
              fprintf (stderr,
                       "Reference row %u opcode %02x slot %u: %04x != %04x\n",
                       row, opcode, i, [cpu state]->stack[i], after[i]);
              exit (1);
            }
          checks++;
        }
      row++;
    }
  CHECK (feof (file));
  CHECK (row > 1000);
  printf ("Compared %u executions with Dwarf\n", row);
  fclose (file);
  [cpu release];
  [memory release];
}
int
main (int argc, char **argv)
{
#ifdef GNUSTEP
  extern char **environ;
  GSInitializeProcess (argc, argv, environ);
#endif

  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  memory_tests ();
  processor_tests ();
  if (argc == 2)
    reference_tests (argv[1]);
  printf ("Passed %u checks\n", checks);
  [pool release];
  return 0;
}
