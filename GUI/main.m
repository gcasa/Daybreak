/* GNUstep Objective-C 1.0 application entry point. See COPYING. */
#import "DBApplication.h"
int
main (int argc, char **argv)
{
#ifdef GNUSTEP
  extern char **environ;
  GSInitializeProcess (argc, argv, environ);
#endif

  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  DBApplication *delegate;
  (void) argc;
  (void) argv;
  [NSApplication sharedApplication];
  delegate = [[DBApplication alloc] init];
  [NSApp setDelegate: (id) delegate];
  [NSApp run];
  [delegate release];
  [pool release];
  return 0;
}
