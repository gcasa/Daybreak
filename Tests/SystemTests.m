/* Regression tests for control, processes, graphics and disk images. See
 * COPYING. */
#import "DBProcessorPrivate.h"
#import "DBDisk.h"
#include <stdio.h>
#include <stdlib.h>
#include <zlib.h>
/* Keep managed-disk tests out of the user's real Library. */
static NSString *workingTestDirectory;
@interface DBTestWorkingDisk : DBDisk
@end
@implementation DBTestWorkingDisk
+ (NSString *) workingDirectory
{
  return workingTestDirectory;
}
@end
static unsigned int checks;
#define CHECK(x)                                                              \
  do                                                                          \
    {                                                                         \
      checks++;                                                               \
      if (!(x))                                                               \
        {                                                                     \
          fprintf (stderr, "FAIL %s:%d: %s\n", __FILE__, __LINE__, #x);       \
          exit (1);                                                           \
        }                                                                     \
    }                                                                         \
  while (0)
static void
put_double (DBMemory *memory, uint32_t address, uint32_t value)
{
  [memory writeWord: address value: value];
  [memory writeWord: address + 1 value: value >> 16];
}
static void
control_tests (BOOL modern)
{
  DBMemory *m = [[DBMemory alloc] initWithRealPages: 1024 virtualPages: 2048];
  DBProcessor *p = [[DBProcessor alloc] initWithMemory: m post40: modern];
  DBProcessorState *s = [p state];
  unsigned int i;
  s->LF = 0x800;
  s->GF16 = 0x1000;
  s->GF32 = 0x1000;
  s->GFI = 4;
  s->CB = 0x30000;
  s->PC = 0x80;
  [m writeWord: 0x104
         value: 0x902]; /* Indirect AV entry to index 0x240 is invalid. */
  [m writeWord: 0x104 value: (5 << 2) | 2];
  [m writeWord: 0x105 value: 0x900];
  [m writeWord: 0x900 value: 1];
  [m writeWord: 0x8fc value: 5];
  CHECK ([p allocateFrame: 4] == 0x900);
  CHECK ([m readWord: 0x105] == 1);
  [p freeFrame: 0x900];
  CHECK ([m readWord: 0x105] == 0x900);
  [m writeWord: 0x7fe value: modern ? 4 : 0x1000];
  if (modern)
    {
      put_double (m, 0x20004, 0x1000);
      put_double (m, 0x20006, 0x30000);
    }
  else
    put_double (m, 0xffe, 0x30000);
  [m writeWord: 0x30010 value: 0x05c1];
  [p call: (0x20U << 16) | (modern ? 7 : 0x1001)];
  CHECK (s->LF == 0x900 && s->PC == 0x21);
  CHECK ([m readWord: 0x7ff] == 0x80);
  CHECK ([m readWord: 0x8fd] == 0x800);
  CHECK ([m readWord: 0x8fe] == (modern ? 4 : 0x1000));
  [p transfer: 0x800 source: 0 type: 0 free: YES];
  CHECK (s->LF == 0x800 && s->PC == 0x80);
  CHECK ([m readWord: 0x105] == 0x900);
  for (i = 0; i < 14; i++)
    s->stack[i] = i * 17;
  s->SP = 3;
  s->breakByte = 0xaa;
  [p saveStack: 0x1500];
  CHECK (s->SP == 0 && [m readWord: 0x150e] == 0xaa03);
  s->stack[13] = 0;
  [p loadStack: 0x1500];
  CHECK (s->SP == 3 && s->stack[13] == 221 && s->breakByte == 0xaa);
  [p release];
  [m release];
}
static void
trap_tests (void)
{
  DBMemory *m = [[DBMemory alloc] initWithRealPages: 1024 virtualPages: 2048];
  DBProcessor *p = [[DBProcessor alloc] initWithMemory: m post40: NO];
  DBProcessorState *s = [p state];
  s->LF = 0x800;
  s->CB = 0x30000;
  s->PC = 0x20;
  put_double (m, 0x21c, 0x900); /* Bounds trap frame. */
  [m writeWord: 0x8fe value: 0x1000];
  [m writeWord: 0x8ff value: 0x40];
  put_double (m, 0xffe, 0x31000);
  [m writeWord: 0x30010 value: 0x3c00]; /* BNDCK. */
  [p push: 8];
  [p push: 4];
  [p setGuestTraps: YES];
  [p step];
  CHECK (s->LF == 0x900 && s->PC == 0x40 && s->CB == 0x31000);
  CHECK (s->SP == 2 && s->WDC == 2 && [m readWord: 0x7ff] == 0x20);
  CHECK ([m readWord: 0x8fd] == 0x800);
  /* Transfer traps restore the interrupted PC/SP before entering the frame. */
  put_double (m, 0x208, 0xa00);
  [m writeWord: 0x9fe value: 0x1000];
  [m writeWord: 0x9ff value: 0x60];
  [m writeWord: 0xffd value: 2];
  s->savedPC = 0x32;
  s->savedSP = 2;
  s->PC = 0x55;
  s->SP = 0;
  s->XTS = 1;
  {
    volatile BOOL caught = NO;
    NS_DURING
    [p checkTransferTrap: 0x12345678 type: 1];
    NS_HANDLER
    CHECK ([[localException name] isEqual: @"DBMesaAbort"]);
    caught = YES;
    NS_ENDHANDLER
    CHECK (caught);
  }
  CHECK (s->LF == 0xa00 && s->PC == 0x60 && s->SP == 2);
  CHECK ([m readWord: 0x8ff] == 0x32);
  CHECK ([m readWord: 0xa00] == 0x5678 && [m readWord: 0xa01] == 0x1234 &&
         [m readWord: 0xa02] == 1);
  [p release];
  [m release];
}
static void
process_tests (void)
{
  DBMemory *m = [[DBMemory alloc] initWithRealPages: 1024 virtualPages: 2048];
  DBProcessor *p = [[DBProcessor alloc] initWithMemory: m post40: NO];
  DBProcessorState *s = [p state];
  uint32_t ready = 0x10000, source = 0x11000, condition = 0x11001;
  /* Insert priorities 2, 6, 4 and preserve stable ordering. */
  unsigned int i;
  static const unsigned int priorities[3] = { 2, 6, 4 };
  for (i = 8; i < 11; i++)
    {
      [m writeWord: source value: i << 3];
      [p setProcessWord: i offset: 0 value: (priorities[i - 8] << 13) | (i << 3)];
      [p requeue: source to: ready process: i];
    }
  CHECK (([m readWord: ready] >> 3 & 1023) == 8);
  CHECK (([p processWord: 8 offset: 0] >> 3 & 1023) == 9);
  CHECK (([p processWord: 9 offset: 0] >> 3 & 1023) == 10);
  [p requeue: ready to: condition process: 9];
  [p setProcessWord: 9 offset: 1 value: 2];
  [p setProcessWord: 9 offset: 3 value: 123];
  CHECK ([p notifyWakeup: condition]);
  CHECK ([p processWord: 9 offset: 1] == 0 && [p processWord: 9 offset: 3] == 0);
  CHECK (![p notifyWakeup: condition]);
  CHECK ([m readWord: condition] == 1);
  /* Save and restore a nonpermanent preempted process and recycle its vector.
   */
  s->PSB = 9;
  s->LF = 0x800;
  s->PC = 0x123;
  s->stack[0] = 0xabcd;
  s->SP = 1;
  [m writeWord: ready + 8 + 6 value: 0x2000];
  [m writeWord: 0x12000 value: 0];
  [p setProcessWord: 9 offset: 4 value: 2];
  [p saveProcess: YES];
  CHECK ([p processWord: 9 offset: 2] == 0x2000 && s->SP == 0);
  CHECK ([m readWord: 0x12000] == 0xabcd && [m readWord: 0x1200f] == 0x800);
  CHECK ([p loadProcess] == 0x800);
  CHECK (s->SP == 1 && s->stack[0] == 0xabcd && s->MDS == 0x20000);
  CHECK ([m readWord: ready + 8 + 6] == 0x2000);
  [p release];
  [m release];
}
static void
block_tests (void)
{
  DBMemory *m = [[DBMemory alloc] initWithRealPages: 1024 virtualPages: 2048];
  DBProcessor *p = [[DBProcessor alloc] initWithMemory: m post40: NO];
  DBProcessorState *s = [p state];
  unsigned int i;
  s->CB = 0x30000;
  [m writeWord: s->CB value: 0xf400];
  [m writeWord: 0x10ff value: 0x1234];
  [m writeWord: 0x1100 value: 0xabcd];
  [p pushLong: 0x10ff];
  [p push: 2];
  [p pushLong: 0x2000];
  [p step];
  CHECK (s->PC == 0 && [m readWord: 0x2000] == 0x1234);
  [m mapPage: 17 to: 0 flags: DB_MAP_VACANT];
  {
    volatile BOOL caught = NO;
    NS_DURING[p step];
    NS_HANDLER caught = [[localException name] isEqual: @"DBPageFault"];
    NS_ENDHANDLER CHECK (caught);
  }
  CHECK (s->PC == 0 && s->SP == 5 && s->stack[0] == 0x1100
         && s->stack[2] == 1);
  [m mapPage: 17 to: 17 flags: 0];
  [p step];
  CHECK (s->PC == 1 && s->SP == 0 && [m readWord: 0x2001] == 0xabcd);
  /* Two XOR scanlines: repeat-PC continuation must not apply row zero twice.
   */
  s->PC = 0;
  [m writeWord: s->CB value: 0xf82b];
  put_double (m, 0x1800, 0x2000);
  [m writeWord: 0x1802 value: 0];
  [m writeWord: 0x1803 value: 16];
  put_double (m, 0x1804, 0x2100);
  [m writeWord: 0x1806 value: 0];
  [m writeWord: 0x1807 value: 16];
  [m writeWord: 0x1808 value: 16];
  [m writeWord: 0x1809 value: 2];
  [m writeWord: 0x180a value: 0x0600];
  for (i = 0; i < 2; i++)
    {
      [m writeWord: 0x2100 + i value: 0xffff];
      [m writeWord: 0x2000 + i value: 0x5555];
    }
  [p push: 0x1800];
  [p step];
  CHECK (s->SP == 2 && s->PC == 0);
  [p step];
  CHECK (s->SP == 0 && s->PC == 2);
  CHECK ([m readWord: 0x2000] == 0xaaaa && [m readWord: 0x2001] == 0xaaaa);
  [p release];
  [m release];
}
static void
be_word (unsigned char *bytes, unsigned int word, uint16_t value)
{
  bytes[word * 2] = value >> 8;
  bytes[word * 2 + 1] = value;
}
static void
disk_tests (void)
{
  NSString *directory = [NSTemporaryDirectory ()
      stringByAppendingPathComponent: [[NSProcessInfo processInfo]
                                         globallyUniqueString]];
  NSString *input =
      [directory stringByAppendingPathComponent: @"fixture.zdisk"];
  NSString *output = [directory stringByAppendingPathComponent: @"copy.zdisk"];
  NSMutableData *raw = [NSMutableData dataWithLength: 12 + 640 * 536];
  NSMutableData *compressed;
  unsigned char *bytes = [raw mutableBytes];
  unsigned int i;
  uLongf length = compressBound ([raw length]);
  DBDisk *disk, *copy;
  [[NSFileManager defaultManager] createDirectoryAtPath: directory
                            withIntermediateDirectories: YES
                                             attributes: nil
                                                  error: NULL];
  be_word (bytes, 0, 0xdaad);
  be_word (bytes, 1, 1);
  be_word (bytes, 2, 40);
  be_word (bytes, 4, 640);
  be_word (bytes, 5, 0x5cc5);
  for (i = 0; i < 640; i++)
    {
      be_word (bytes + 12 + i * 536, 1, i);
      be_word (bytes + 16 + i * 536, 10, i);
    }
  /* Physical volume root points at sector one; single-page germ terminates. */
  be_word (bytes + 16, 10, 0xa28a);
  be_word (bytes + 16, 10 + 0x22, 1);
  be_word (bytes + 16 + 536, 8, 65535);
  be_word (bytes + 16 + 536, 9, 65535);
  compressed = [NSMutableData dataWithLength: length];
  CHECK (compress2 ([compressed mutableBytes], &length, [raw bytes],
                    [raw length], 1)
         == Z_OK);
  [compressed setLength: length];
  CHECK ([compressed writeToFile: input atomically: YES]);
  disk = [[DBDisk alloc] initWithPath: input];
  CHECK ([disk heads] == 1 && [disk cylinders] == 40 &&
         [disk sectorCount] == 640);
  CHECK ([[disk germ] length] == 512 &&
         [disk wordAtSector: 123 offset: 10] == 123);
  [disk writeSector: 123 offset: 10 value: 0xbeef];
  CHECK ([disk changed]);
  [disk saveCopyToPath: output];
  CHECK (![disk changed]);
  copy = [[DBDisk alloc] initWithPath: output];
  CHECK ([copy wordAtSector: 123 offset: 10] == 0xbeef);
  [copy release];
  copy = [[DBDisk alloc] initWithPath: input];
  CHECK ([copy wordAtSector: 123 offset: 10] == 123);
  [copy release];
  {
    volatile BOOL caught = NO;
    NS_DURING [disk saveCopyToPath: input];
    NS_HANDLER caught = [[localException name] isEqual: @"DBDiskError"];
    NS_ENDHANDLER CHECK (caught);
  }
  [disk release];
  {
    NSString *workingPath;
    NSData *original = [NSData dataWithContentsOfFile: input];
    volatile BOOL caught = NO;
    workingTestDirectory =
        [directory stringByAppendingPathComponent: @"Library"];
    disk = [[DBTestWorkingDisk alloc] initWithWorkingCopyOfPath: input];
    workingPath = [[disk path] copy];
    CHECK (![workingPath isEqual: input]);
    CHECK ([workingPath hasPrefix: workingTestDirectory]);
    [disk writeSector: 123 offset: 10 value: 0x1234];
    [disk saveCopyToPath: output];
    CHECK ([disk changed]);
    NS_DURING [disk saveCopyToPath: input];
    NS_HANDLER caught = [[localException name] isEqual: @"DBDiskError"];
    NS_ENDHANDLER CHECK (caught);
    [disk saveWorkingCopy];
    CHECK (![disk changed]);
    {
      NSString *backup = [[workingPath stringByDeletingPathExtension]
          stringByAppendingString: @".previous.zdisk"];
      DBDisk *previous = [[DBDisk alloc] initWithPath: backup];
      CHECK ([previous wordAtSector: 123 offset: 10] == 123);
      [previous release];
    }
    [disk release];
    disk = [[DBTestWorkingDisk alloc] initWithWorkingCopyOfPath: workingPath];
    CHECK ([[disk path] isEqual: workingPath]);
    CHECK ([disk wordAtSector: 123 offset: 10] == 0x1234);
    [disk release];
    disk = [[DBTestWorkingDisk alloc] initWithWorkingCopyOfPath: input];
    CHECK (![[disk path] isEqual: workingPath]);
    CHECK ([disk wordAtSector: 123 offset: 10] == 123);
    CHECK ([[NSData dataWithContentsOfFile: input] isEqual: original]);
    /* A failed save must retain pending changes for retry. */
    [[NSFileManager defaultManager]
        removeItemAtPath: [[disk path] stringByDeletingLastPathComponent]
                   error: NULL];
    [disk writeSector: 123 offset: 10 value: 1];
    caught = NO;
    NS_DURING[disk saveWorkingCopy];
    NS_HANDLER caught = [[localException name] isEqual: @"DBDiskError"];
    NS_ENDHANDLER CHECK (caught && [disk changed]);
    [disk release];
    /* Imported deltas are flattened, leaving both source files unchanged. */
    be_word (bytes + 16 + 123 * 536, 10, 0x5678);
    length = compressBound ([raw length]);
    [compressed setLength: length];
    CHECK (compress2 ([compressed mutableBytes], &length, [raw bytes],
                      [raw length], 1)
           == Z_OK);
    [compressed setLength: length];
    CHECK ([compressed writeToFile: [input stringByAppendingString: @".zdelta"]
                        atomically: YES]);
    disk = [[DBTestWorkingDisk alloc] initWithWorkingCopyOfPath: input];
    CHECK ([disk wordAtSector: 123 offset: 10] == 0x5678);
    [disk writeSector: 123 offset: 10 value: 0x9abc];
    [disk saveWorkingCopy];
    CHECK ([[NSData dataWithContentsOfFile: input] isEqual: original]);
    CHECK ([[NSData
        dataWithContentsOfFile: [input stringByAppendingString: @".zdelta"]]
        isEqual: compressed]);
    [disk release];
    [workingPath release];
  }
  [compressed setLength: [compressed length] / 2];
  CHECK ([compressed writeToFile: output atomically: YES]);
  {
    volatile BOOL caught = NO;
    NS_DURING copy = [[DBDisk alloc] initWithPath: output];
    [copy release];
    NS_HANDLER caught = [[localException name] isEqual: @"DBDiskError"];
    NS_ENDHANDLER CHECK (caught);
  }
  [[NSFileManager defaultManager] removeItemAtPath: directory error: NULL];
}

int
main (int argc, char **argv)
{
#ifdef GNUSTEP
  extern char **environ;
  GSInitializeProcess (argc, argv, environ);
#endif

  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  (void) argc;
  (void) argv;
  disk_tests ();
  control_tests (NO);
  control_tests (YES);
  trap_tests ();
  process_tests ();
  block_tests ();
  printf ("Passed %u system checks\n", checks);
  [pool release];
  return 0;
}
