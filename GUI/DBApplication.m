/* GNUstep Objective-C 1.0 desktop interface. See COPYING. */
#import "DBApplication.h"

static int
db_key (unichar character)
{
  static const unsigned char letters[26]
      = { 37, 55, 53, 21, 19, 51, 66, 68, 39, 54, 25, 42, 71,
          70, 41, 27, 35, 64, 36, 65, 22, 23, 34, 40, 67, 56 };
  static const unsigned char digits[10]
      = { 24, 48, 33, 32, 17, 16, 18, 20, 69, 38 };
  if (character >= 'A' && character <= 'Z')
    character += 'a' - 'A';
  if (character >= 'a' && character <= 'z')
    return letters[character - 'a'];
  if (character >= '0' && character <= '9')
    return digits[character - '0'];
  switch (character)
    {
    case ' ':
      return 73;
    case '\t':
      return 49;
    case '\r':
    case '\n':
      return 60;
    case 127:
    case 8:
      return 31;
    case 27:
      return 77;
    case '-':
      return 26;
    case '=':
      return 75;
    case '[':
      return 74;
    case ']':
      return 45;
    case ';':
      return 59;
    case '\'':
      return 7;
    case '`':
      return 61;
    case ',':
      return 43;
    case '.':
      return 58;
    case '/':
      return 28;
    case NSF1FunctionKey:
      return 92;
    case NSF2FunctionKey:
      return 52;
    case NSF3FunctionKey:
      return 89;
    case NSF4FunctionKey:
      return 78;
    case NSF5FunctionKey:
      return 90;
    case NSF6FunctionKey:
      return 46;
    case NSF7FunctionKey:
      return 79;
    case NSF8FunctionKey:
      return 91;
    case NSDeleteFunctionKey:
      return 62;
    case NSHomeFunctionKey:
      return 47;
    default:
      return -1;
    }
}

@implementation DBDisplayView
- (id) initWithFrame: (NSRect)frame
{
  self = [super initWithFrame: frame];
  if (self != nil)
    _pressedKeys = [[NSMutableDictionary alloc] init];
  return self;
}
- (void) dealloc
{
  [_machine release];
  [_pressedKeys release];
  [super dealloc];
}
- (BOOL) acceptsFirstResponder
{
  return YES;
}
- (BOOL) isFlipped
{
  return NO;
}
- (void) setMachine: (DBMachine *)machine
{
  [self releaseInput];
  [machine retain];
  [_machine release];
  _machine = machine;
  [self setNeedsDisplay: YES];
}
- (void) releaseInput
{
  [NSObject cancelPreviousPerformRequestsWithTarget: self];
  [_machine releaseKeys];
  [_pressedKeys removeAllObjects];
}
- (void) drawRect: (NSRect)rect
{
  NSBitmapImageRep *bitmap;
  NSImage *image;
  NSData *data;
  unsigned char *bytes;
  const unsigned char *source;
  NSUInteger i;
  [[NSColor blackColor] set];
  NSRectFill (rect);
  if (_machine == nil || ![_machine displayEnabled])
    return;
  data = [_machine displayData];
  source = [data bytes];
  bitmap = [[NSBitmapImageRep alloc]
      initWithBitmapDataPlanes: NULL
                    pixelsWide: 832
                    pixelsHigh: 633
                 bitsPerSample: 1
               samplesPerPixel: 1
                      hasAlpha: NO
                      isPlanar: NO
                colorSpaceName: NSDeviceWhiteColorSpace
                   bytesPerRow: 104
                  bitsPerPixel: 1];
  bytes = [bitmap bitmapData];
  for (i = 0; i < [data length]; i++)
    bytes[i] = ~source[i];
  image = [[NSImage alloc] initWithSize: NSMakeSize (832, 633)];
  [image addRepresentation: bitmap];
  [image drawInRect: [self bounds]
           fromRect: NSMakeRect (0, 0, 832, 633)
          operation: NSCompositeCopy
           fraction: 1.0];
  [image release];
  [bitmap release];
}
- (void) keyEvent: (NSEvent *)event pressed: (BOOL)pressed
{
  NSNumber *host = [NSNumber numberWithUnsignedInt: [event keyCode]];
  NSNumber *key = [_pressedKeys objectForKey: host];
  if (pressed && key == nil)
    {
      NSString *characters = [event charactersIgnoringModifiers];
      int code =
          [characters length] ? db_key ([characters characterAtIndex: 0]) : -1;
      if (code < 0)
        return;
      key = [NSNumber numberWithInt: code];
      [_pressedKeys setObject: key forKey: host];
    }
  if (key == nil)
    return;
  if (pressed)
    {
      [NSObject cancelPreviousPerformRequestsWithTarget: self
                                               selector: @selector (releaseKey: )
                                                 object: key];
      [_machine setKey: [key unsignedIntValue] pressed: YES];
    }
  else
    [self performSelector: @selector (releaseKey: )
               withObject: key
               afterDelay: 0.06];
  if (!pressed)
    [_pressedKeys removeObjectForKey: host];
}
- (void) releaseKey: (NSNumber *)key
{
  [_machine setKey: [key unsignedIntValue] pressed: NO];
}
- (void) keyDown: (NSEvent *)event
{
  [self keyEvent: event pressed: YES];
}
- (void) keyUp: (NSEvent *)event
{
  [self keyEvent: event pressed: NO];
}
- (void) flagsChanged: (NSEvent *)event
{
  NSUInteger flags = [event modifierFlags];
  [_machine setKey: 57 pressed: (flags & NSShiftKeyMask) != 0];
  [_machine setKey: 72 pressed: (flags & NSAlphaShiftKeyMask) != 0];
  [_machine setKey: 47 pressed: (flags & NSControlKeyMask) != 0];
}
- (void) updateMouse: (NSEvent *)event
{
  NSPoint point = [self convertPoint: [event locationInWindow] fromView: nil];
  NSRect bounds = [self bounds];
  int x = point.x * 832 / bounds.size.width,
      y = 633 - point.y * 633 / bounds.size.height;
  [_machine setMouseX: MAX (0, MIN (831, x)) y: MAX (0, MIN (632, y))];
}
- (void) mouseMoved: (NSEvent *)event
{
  [self updateMouse: event];
}
- (void) mouseDragged: (NSEvent *)event
{
  [self updateMouse: event];
}
- (void) rightMouseDragged: (NSEvent *)event
{
  [self updateMouse: event];
}
- (void) otherMouseDragged: (NSEvent *)event
{
  [self updateMouse: event];
}
- (void) mouseDown: (NSEvent *)event
{
  [[self window] makeFirstResponder: self];
  [self updateMouse: event];
  [NSObject
      cancelPreviousPerformRequestsWithTarget: self
                                     selector: @selector (releaseKey: )
                                       object: [NSNumber numberWithInt: 13]];
  [_machine setKey: 13 pressed: YES];
}
- (void) mouseUp: (NSEvent *)event
{
  [self updateMouse: event];
  [self performSelector: @selector (releaseKey: )
             withObject: [NSNumber numberWithInt: 13]
             afterDelay: 0.06];
}
- (void) rightMouseDown: (NSEvent *)event
{
  [self updateMouse: event];
  [NSObject
      cancelPreviousPerformRequestsWithTarget: self
                                     selector: @selector (releaseKey: )
                                       object: [NSNumber numberWithInt: 14]];
  [_machine setKey: 14 pressed: YES];
}
- (void) rightMouseUp: (NSEvent *)event
{
  [self updateMouse: event];
  [self performSelector: @selector (releaseKey: )
             withObject: [NSNumber numberWithInt: 14]
             afterDelay: 0.06];
}
- (void) otherMouseDown: (NSEvent *)event
{
  [self updateMouse: event];
  [NSObject
      cancelPreviousPerformRequestsWithTarget: self
                                     selector: @selector (releaseKey: )
                                       object: [NSNumber numberWithInt: 15]];
  [_machine setKey: 15 pressed: YES];
}
- (void) otherMouseUp: (NSEvent *)event
{
  [self updateMouse: event];
  [self performSelector: @selector (releaseKey: )
             withObject: [NSNumber numberWithInt: 15]
             afterDelay: 0.06];
}
@end

static NSButton *
db_button (NSView *parent, NSString *title, id target, SEL action, CGFloat x)
{
  NSButton *button = [[[NSButton alloc]
      initWithFrame: NSMakeRect (x, 691, 108, 28)] autorelease];
  [button setTitle: title];
  [button setTarget: target];
  [button setAction: action];
  [button setBezelStyle: NSRoundedBezelStyle];
  [button setAutoresizingMask: NSViewMinYMargin];
  [parent addSubview: button];
  return button;
}

@implementation DBApplication
- (void) applicationDidFinishLaunching: (NSNotification *)notification
{
  NSView *content;
  NSMenu *menu, *applicationMenu, *editMenu;
  NSMenuItem *item;
  NSArray *arguments = [[NSProcessInfo processInfo] arguments];
  (void) notification;
  menu = [[[NSMenu alloc] initWithTitle: @"Daybreak"] autorelease];
  applicationMenu = [[[NSMenu alloc] initWithTitle: @"Daybreak"] autorelease];
  item = [[[NSMenuItem alloc] initWithTitle: @"Daybreak"
                                     action: NULL
                              keyEquivalent: @""] autorelease];
  [menu addItem: item];
  [menu setSubmenu: applicationMenu forItem: item];
  item = [applicationMenu addItemWithTitle: @"Open Disk…"
                                    action: @selector (openDisk: )
                             keyEquivalent: @"o"];
  [item setTarget: self];
  item = [applicationMenu addItemWithTitle: @"Save Disk Copy…"
                                    action: @selector (saveDisk: )
                             keyEquivalent: @"s"];
  [item setTarget: self];
  item = [applicationMenu addItemWithTitle: @"Insert Floppy…"
                                    action: @selector (insertFloppy: )
                             keyEquivalent: @"i"];
  [item setTarget: self];
  item = [applicationMenu addItemWithTitle: @"Eject Floppy"
                                    action: @selector (ejectFloppy: )
                             keyEquivalent: @"e"];
  [item setTarget: self];
  item = [applicationMenu addItemWithTitle: @"Save Floppy Copy…"
                                    action: @selector (saveFloppy: )
                             keyEquivalent: @""];
  [item setTarget: self];
  item = [applicationMenu addItemWithTitle: @"Network…"
                                    action: @selector (configureNetwork: )
                             keyEquivalent: @"n"];
  [item setTarget: self];
  [applicationMenu addItem: [NSMenuItem separatorItem]];
  [applicationMenu addItemWithTitle: @"Quit Daybreak"
                             action: @selector (terminate: )
                      keyEquivalent: @"q"];
  editMenu = [[[NSMenu alloc] initWithTitle: @"Edit"] autorelease];
  item = [[[NSMenuItem alloc] initWithTitle: @"Edit"
                                     action: NULL
                              keyEquivalent: @""] autorelease];
  [menu addItem: item];
  [menu setSubmenu: editMenu forItem: item];
  [editMenu addItemWithTitle: @"Cut"
                      action: @selector (cut: )
               keyEquivalent: @"x"];
  [editMenu addItemWithTitle: @"Copy"
                      action: @selector (copy: )
               keyEquivalent: @"c"];
  [editMenu addItemWithTitle: @"Paste"
                      action: @selector (paste: )
               keyEquivalent: @"v"];
  [editMenu addItemWithTitle: @"Select All"
                      action: @selector (selectAll: )
               keyEquivalent: @"a"];
  [NSApp setMainMenu: menu];
  _window = [[NSWindow alloc]
      initWithContentRect: NSMakeRect (80, 60, 856, 731)
                styleMask: NSTitledWindowMask | NSClosableWindowMask
                          | NSMiniaturizableWindowMask
                  backing: NSBackingStoreBuffered
                    defer: NO];
  [_window setReleasedWhenClosed: NO];
  [_window setTitle: @"Daybreak — Draco 6085"];
  [_window setDelegate: (id) self];
  [_window setAcceptsMouseMovedEvents: YES];
  content = [_window contentView];
  _display =
      [[DBDisplayView alloc] initWithFrame: NSMakeRect (12, 53, 832, 633)];
  [content addSubview: _display];
  db_button (content, @"Open Disk…", self, @selector (openDisk: ), 12);
  _pauseButton = db_button (content, @"Pause", self, @selector (pause: ), 126);
  db_button (content, @"Step", self, @selector (step: ), 240);
  db_button (content, @"Save Copy…", self, @selector (saveDisk: ), 354);
  _status = [[NSTextField alloc] initWithFrame: NSMakeRect (12, 28, 832, 21)];
  [_status setEditable: NO];
  [_status setBezeled: NO];
  [_status setDrawsBackground: NO];
  [_status setStringValue: @"Open an XDE or ViewPoint .zdisk image to boot."];
  [content addSubview: _status];
  _mediaStatus =
      [[NSTextField alloc] initWithFrame: NSMakeRect (12, 5, 832, 21)];
  [_mediaStatus setEditable: NO];
  [_mediaStatus setBezeled: NO];
  [_mediaStatus setDrawsBackground: NO];
  [_mediaStatus setStringValue: @"Floppy empty   •   Network offline"];
  [content addSubview: _mediaStatus];
  db_button (content, @"Floppy…", self, @selector (insertFloppy: ), 468);
  db_button (content, @"Eject", self, @selector (ejectFloppy: ), 582);
  db_button (content, @"Network…", self, @selector (configureNetwork: ), 696);
  [_window makeKeyAndOrderFront: nil];
  [_window makeFirstResponder: _display];
  _timer = [[NSTimer scheduledTimerWithTimeInterval: 0.01
                                             target: self
                                           selector: @selector (tick: )
                                           userInfo: nil
                                            repeats: YES] retain];
  if ([arguments count] > 1 && ![[arguments objectAtIndex: 1] hasPrefix: @"-"])
    [self loadDisk: [arguments objectAtIndex: 1]];
  else
    {
      NSString *last = [[NSUserDefaults standardUserDefaults]
          stringForKey: @"LastHardDisk"];
      if (last != nil)
        [self loadDisk: last];
    }
}
- (void) dealloc
{
  [_timer invalidate];
  [_timer release];
  [_machine release];
  [_display release];
  [_status release];
  [_mediaStatus release];
  [_hubHost release];
  [_window release];
  [super dealloc];
}
- (void) applicationDidResignActive: (NSNotification *)notification
{
  (void) notification;
  [_display releaseInput];
}
- (void) windowDidResignKey: (NSNotification *)notification
{
  (void) notification;
  [_display releaseInput];
}
- (BOOL) windowShouldClose: (id)sender
{
  (void) sender;
  [NSApp terminate: self];
  return NO;
}
- (BOOL) applicationShouldTerminateAfterLastWindowClosed:
    (NSApplication *)application
{
  (void) application;
  return YES;
}
- (BOOL) mayDiscardDisk
{
  if (![self mayDiscardFloppy])
    return NO;
  NS_DURING
  [[_machine disk] saveWorkingCopy];
  NS_HANDLER
  [self reportException: localException];
  return NO;
  NS_ENDHANDLER
  return YES;
}
- (NSApplicationTerminateReply) applicationShouldTerminate:
    (NSApplication *)application
{
  (void) application;
  return [self mayDiscardDisk] ? NSTerminateNow : NSTerminateCancel;
}
- (void) openDisk: (id)sender
{
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  (void) sender;
  [panel setAllowsMultipleSelection: NO];
  [panel setDirectory: [[[NSBundle mainBundle] resourcePath]
      stringByAppendingPathComponent: @"disks-6085"]];
  if ([panel runModalForTypes: [NSArray arrayWithObject: @"zdisk"]] == NSOKButton
      && [self mayDiscardDisk])
    [self loadDisk: [panel filename]];
}
- (void) loadDisk: (NSString *)path
{
  NS_DURING
  DBMachine *machine = [[DBMachine alloc] initWithDisk: path switches: nil workingCopy: YES];
  [_display setMachine: machine];
  [_machine release];
  _machine = machine;
  if (_hubHost != nil)
    [_machine setNetworkHost: _hubHost port: _hubPort];
  _paused = NO;
  [[NSUserDefaults standardUserDefaults] setObject: [[_machine disk] path]
                                           forKey: @"LastHardDisk"];
  [_window setTitle: [NSString stringWithFormat: @"Daybreak — %@",
                                               [path lastPathComponent]]];
  [_pauseButton setTitle: @"Pause"];
  [_window makeFirstResponder: _display];
  [self refresh];
  NS_HANDLER
  [self reportException: localException];
  NS_ENDHANDLER
}

- (BOOL) mayDiscardFloppy
{
  if (![[_machine floppy] changed])
    return YES;
  return NSRunAlertPanel (
             @"Unsaved floppy changes",
             @"Save a floppy copy to keep changes before ejecting or closing.",
             @"Cancel", @"Discard Changes", nil)
         == NSAlertAlternateReturn;
}
- (void) insertFloppy: (id)sender
{
  NSOpenPanel *panel;
  NSButton *protect;
  (void) sender;
  if (_machine == nil)
    return;
  panel = [NSOpenPanel openPanel];
  protect = [[[NSButton alloc] initWithFrame: NSMakeRect (0, 0, 300, 28)]
      autorelease];
  [protect setButtonType: NSSwitchButton];
  [protect setTitle: @"Write protect (DMK is always protected)"];
  [panel setAccessoryView: protect];
  [panel setAllowsMultipleSelection: NO];
  if ([panel runModalForTypes: [NSArray arrayWithObjects: @"imd", @"dmk", nil]]
          != NSOKButton
      || ![self mayDiscardFloppy])
    return;
  NS_DURING
  /* Validate before discarding any previous session changes. */
  DBFloppy *probe =
      [[DBFloppy alloc] initWithPath: [panel filename]
                            readOnly: [protect state] == NSOnState];
  [probe release];
  if ([[_machine floppy] changed])
    [_machine ejectFloppyDiscardingChanges: YES];
  [_machine insertFloppy: [panel filename]
                readOnly: [protect state] == NSOnState];
  [self refresh];
  NS_HANDLER
  NSRunAlertPanel (@"Cannot insert floppy", @"%@", @"OK", nil, nil,
                   [localException reason]);
  NS_ENDHANDLER
}
- (void) ejectFloppy: (id)sender
{
  (void) sender;
  if (![self mayDiscardFloppy])
    return;
  [_machine ejectFloppyDiscardingChanges: YES];
  [self refresh];
}
- (void) saveFloppy: (id)sender
{
  NSSavePanel *panel;
  (void) sender;
  if ([_machine floppy] == nil)
    return;
  panel = [NSSavePanel savePanel];
  [panel setRequiredFileType: @"imd"];
  if ([panel runModalForDirectory: nil file: @"Floppy-copy.imd"] != NSOKButton)
    return;
  NS_DURING
  [[_machine floppy] saveCopyToPath: [panel filename]];
  [self refresh];
  NS_HANDLER
  NSRunAlertPanel (@"Cannot save floppy", @"%@", @"OK", nil, nil,
                   [localException reason]);
  NS_ENDHANDLER
}
- (void) finishNetworkPanel: (id)sender
{
  [NSApp stopModalWithCode: [sender tag]];
}
- (void) configureNetwork: (id)sender
{
  NSPanel *panel;
  NSTextField *host, *port, *label;
  NSButton *button;
  NSView *content;
  int answer;
  unsigned int i;
  (void) sender;
  panel = [[NSPanel alloc] initWithContentRect: NSMakeRect (150, 180, 460, 180)
                                     styleMask: NSTitledWindowMask
                                       backing: NSBackingStoreBuffered
                                         defer: NO];
  [panel setTitle: @"NetHub connection"];
  [panel setHidesOnDeactivate: NO];
  content = [panel contentView];
  label = [[[NSTextField alloc] initWithFrame: NSMakeRect (16, 140, 425, 22)]
      autorelease];
  [label setStringValue: @"NetHub host and TCP port (default 3333)"];
  [label setEditable: NO];
  [label setBezeled: NO];
  [label setDrawsBackground: NO];
  [content addSubview: label];
  host = [[[NSTextField alloc] initWithFrame: NSMakeRect (16, 103, 315, 24)]
      autorelease];
  port = [[[NSTextField alloc] initWithFrame: NSMakeRect (345, 103, 95, 24)]
      autorelease];
  [host setStringValue: _hubHost ? _hubHost : @"localhost"];
  [port setStringValue: [NSString stringWithFormat: @"%u",
                                                  _hubPort ? _hubPort : 3333]];
  [content addSubview: host];
  [content addSubview: port];
  for (i = 0; i < 3; i++)
    {
      button = [[[NSButton alloc]
          initWithFrame: NSMakeRect (16 + i * 145, 24, 135, 32)] autorelease];
      [button setTitle: i == 0   ? @"Cancel"
                       : i == 1 ? @"Disconnect"
                                : @"Connect"];
      [button setTag: i];
      [button setTarget: self];
      [button setAction: @selector (finishNetworkPanel: )];
      [button setBezelStyle: NSRoundedBezelStyle];
      [content addSubview: button];
    }
  [panel makeFirstResponder: host];
  [panel center];
  answer = (int) [NSApp runModalForWindow: panel];
  [panel orderOut: nil];
  if (answer == 1)
    {
      [_machine setNetworkHost: nil port: 0];
      [_hubHost release];
      _hubHost = nil;
    }
  else if (answer == 2)
    {
      NS_DURING
      NSString *name = [[host stringValue]
          stringByTrimmingCharactersInSet:
              [NSCharacterSet whitespaceAndNewlineCharacterSet]];
      NSScanner *scanner = [NSScanner scannerWithString: [port stringValue]];
      int number;
      if (![scanner scanInt: &number] || ![scanner isAtEnd] || number < 1
          || number > 65535 || [name length] == 0)
        [NSException raise: @"DBNetworkError"
                    format: @"Enter a host and port 1..65535"];
      if (_machine == nil)
        [NSException raise: @"DBNetworkError"
                    format: @"Open a workstation disk before connecting"];
      [_machine setNetworkHost: name port: number];
      [_hubHost release];
      _hubHost = [name copy];
      _hubPort = number;
      NS_HANDLER
      NSRunAlertPanel (@"Cannot configure network", @"%@", @"OK", nil, nil,
                       [localException reason]);
      NS_ENDHANDLER
    }
  [panel release];
  [self refresh];
}

- (void) pause: (id)sender
{
  (void) sender;
  _paused = !_paused;
  [_pauseButton setTitle: _paused ? @"Resume" : @"Pause"];
  [self refresh];
}
- (void) step: (id)sender
{
  (void) sender;
  _paused = YES;
  [_pauseButton setTitle: @"Resume"];
  NS_DURING
  [_machine runForInstructions: 1];
  [self refresh];
  NS_HANDLER
  [self reportException: localException];
  NS_ENDHANDLER
}
- (void) saveDisk: (id)sender
{
  NSSavePanel *panel;
  (void) sender;
  if (_machine == nil)
    return;
  panel = [NSSavePanel savePanel];
  [panel setRequiredFileType: @"zdisk"];
  if ([panel runModalForDirectory: nil file: @"Session.zdisk"] != NSOKButton)
    return;
  NS_DURING
  [[_machine disk] saveCopyToPath: [panel filename]];
  NS_HANDLER
  [self reportException: localException];
  NS_ENDHANDLER
}
- (void) tick: (NSTimer *)timer
{
  NSAutoreleasePool *pool = [NSAutoreleasePool new];
  (void) timer;
  NS_DURING
  if (!_paused)
    [_machine runForInstructions: 50000];
  else
    [_machine pollDevices];
  if (_machine != nil)
    [self refresh];
  NS_HANDLER
  [self reportException: localException];
  NS_ENDHANDLER
  [pool release];
}
- (void) refresh
{
  DBProcessorState *state;
  if (_machine == nil)
    return;
  state = [_machine state];
  [_status
      setStringValue: [NSString
                         stringWithFormat: @"%@   MP %04u   Instructions %llu  "
                                          @" Disk R %llu / W %llu   %@",
                                          [_machine halted] ? @"Halted"
                                          : _paused         ? @"Paused"
                                          : state->running  ? @"Running"
                                                            : @"Waiting",
                                          state->MP,
                                          (unsigned long long)
                                              state->instructions,
                                          (unsigned long long)
                                              [_machine diskReads],
                                          (unsigned long long)
                                              [_machine diskWrites],
                                          @""]];
  [_mediaStatus
      setStringValue:
          [NSString stringWithFormat:
                        @"Floppy: %@%@   •   Network: %@   TX %llu / RX %llu",
                        [_machine floppy]
                            ? [[[_machine floppy] path] lastPathComponent]
                            : @"empty",
                        [[_machine floppy] readOnly]  ? @" (protected)"
                        : [[_machine floppy] changed] ? @" (modified)"
                                                      : @"",
                        [_machine network] ? [[_machine network] status]
                                           : @"offline",
                        (unsigned long long) [_machine packetsSent],
                        (unsigned long long) [_machine packetsReceived]]];
  [_display setNeedsDisplay: YES];
}
- (void) reportException: (NSException *)exception
{
  _paused = YES;
  [_pauseButton setTitle: @"Resume"];
  [_status setStringValue: [NSString stringWithFormat: @"Stopped: %@ — %@",
                                                     [exception name],
                                                     [exception reason]]];
  NSRunAlertPanel (@"Emulation stopped", @"%@\n%@", @"OK", nil, nil,
                   [exception name], [exception reason]);
}
@end
