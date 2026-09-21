/* GNUstep Objective-C 1.0 desktop interface. See COPYING. */
#import "DBApplication.h"
#import "DBDuchess.h"

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
  [_pasteKeys release];
  [_guestCursor release];
  [_cursorShape release];
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
  [_pasteKeys removeAllObjects];
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
  if (![_cursorShape isEqual: [_machine cursorData]])
    {
      NSBitmapImageRep *cursor = [[NSBitmapImageRep alloc]
          initWithBitmapDataPlanes: NULL
                        pixelsWide: 16
                        pixelsHigh: 16
                     bitsPerSample: 8
                   samplesPerPixel: 4
                          hasAlpha: YES
                          isPlanar: NO
                    colorSpaceName: NSDeviceRGBColorSpace
                       bytesPerRow: 64
                      bitsPerPixel: 32];
      NSImage *cursorImage =
          [[NSImage alloc] initWithSize: NSMakeSize (16, 16)];
      unsigned int x, y;
      const uint16_t *shape;
      [_cursorShape release];
      _cursorShape = [[_machine cursorData] copy];
      shape = [_cursorShape bytes];
      memset ([cursor bitmapData], 0, 1024);
      for (y = 0; y < 16; y++)
        for (x = 0; x < 16; x++)
          [cursor bitmapData][(y * 16 + x) * 4 + 3]
              = shape[y] & (0x8000 >> x) ? 255 : 0;
      [cursorImage addRepresentation: cursor];
      [_guestCursor release];
      _guestCursor = [[NSCursor alloc] initWithImage: cursorImage
                                             hotSpot: NSZeroPoint];
      [cursor release];
      [cursorImage release];
      [[self window] invalidateCursorRectsForView: self];
    }
  data = [_machine displayRGB];
  source = [data bytes];
  bitmap = [[NSBitmapImageRep alloc]
      initWithBitmapDataPlanes: NULL
                    pixelsWide: [_machine displayWidth]
                    pixelsHigh: [_machine displayHeight]
                 bitsPerSample: 8
               samplesPerPixel: 3
                      hasAlpha: NO
                      isPlanar: NO
                colorSpaceName: NSDeviceRGBColorSpace
                   bytesPerRow: [_machine displayWidth] * 3
                  bitsPerPixel: 24];
  bytes = [bitmap bitmapData];
  for (i = 0; i < [data length]; i++)
    bytes[i] = source[i];
  image = [[NSImage alloc] initWithSize: NSMakeSize ([_machine displayWidth],
                                                    [_machine displayHeight])];
  [image addRepresentation: bitmap];
  [NSGraphicsContext saveGraphicsState];
  [[NSGraphicsContext currentContext]
      setImageInterpolation: NSImageInterpolationNone];
  [image drawInRect: [self bounds]
           fromRect: NSMakeRect (0, 0, [_machine displayWidth],
                                [_machine displayHeight])
          operation: NSCompositeCopy
           fraction: 1.0];
  [NSGraphicsContext restoreGraphicsState];
  [image release];
  [bitmap release];
}
- (void) resetCursorRects
{
  [self addCursorRect: [self bounds]
               cursor: _guestCursor ? _guestCursor : [NSCursor arrowCursor]];
}
- (void) copy: (id)sender
{
  NSPasteboard *pasteboard = [NSPasteboard generalPasteboard];
  NSBitmapImageRep *bitmap =
      [self bitmapImageRepForCachingDisplayInRect: [self bounds]];
  (void) sender;
  [self cacheDisplayInRect: [self bounds] toBitmapImageRep: bitmap];
  [pasteboard declareTypes: [NSArray arrayWithObject: NSTIFFPboardType]
                     owner: nil];
  [pasteboard setData: [bitmap TIFFRepresentation] forType: NSTIFFPboardType];
}
- (void) print: (id)sender
{
  (void) sender;
  [[NSPrintOperation printOperationWithView: self] runOperation];
}
- (void) paste: (id)sender
{
  NSString *text =
      [[NSPasteboard generalPasteboard] stringForType: NSStringPboardType];
  unsigned int i;
  (void) sender;
  [self releaseInput];
  if (_pasteKeys == nil)
    _pasteKeys = [[NSMutableArray alloc] init];
  for (i = 0; i < [text length] && i < 65536; i++)
    {
      unichar c = [text characterAtIndex: i];
      NSString *shifted = @"!@#$%^&*()_+{}:\"~<>?|";
      NSString *plain = @"1234567890-=[];'`,./\\";
      NSRange match =
          [shifted rangeOfString: [NSString stringWithCharacters: &c length: 1]];
      BOOL shift = (c >= 'A' && c <= 'Z') || match.location != NSNotFound;
      int key;
      if (match.location != NSNotFound)
        c = [plain characterAtIndex: match.location];
      key = db_key (c);
      if (key >= 0)
        [_pasteKeys
            addObject: [NSNumber numberWithInt: key | (shift ? 256 : 0)]];
    }
  [self pasteNext: nil];
}
- (void) pasteNext: (id)sender
{
  unsigned int key;
  (void) sender;
  [_machine setKey: 57 pressed: NO];
  if ([_pasteKeys count] == 0)
    return;
  key = [[_pasteKeys objectAtIndex: 0] unsignedIntValue];
  [_pasteKeys removeObjectAtIndex: 0];
  [_machine setKey: 57 pressed: (key & 256) != 0];
  [_machine setKey: key & 255 pressed: YES];
  [self performSelector: @selector (releaseKey: )
             withObject: [NSNumber numberWithUnsignedInt: key & 255]
             afterDelay: 0.06];
  [self performSelector: @selector (pasteNext: ) withObject: nil afterDelay: 0.12];
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
      NSDictionary *mapping = [[NSUserDefaults standardUserDefaults]
          dictionaryForKey: @"KeyboardMap"];
      NSNumber *custom = [mapping objectForKey: [host stringValue]];
      if (custom != nil)
        code = [custom intValue];
      if (code < 0 || code >= 112)
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
  int width = [_machine displayWidth], height = [_machine displayHeight];
  int x = point.x * width / bounds.size.width,
      y = height - point.y * height / bounds.size.height;
  [_machine setMouseX: MAX (0, MIN (width - 1, x))
                    y: MAX (0, MIN (height - 1, y))];
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
- (BOOL) application: (NSApplication *)application openFile: (NSString *)path
{
  (void) application;
  if (_window == nil)
    {
      [_pendingOpenPath release];
      _pendingOpenPath = [path copy];
      return YES;
    }
  if (![self mayDiscardDisk])
    return NO;
  [self loadDisk: path];
  return !_paused;
}
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
  item = [applicationMenu addItemWithTitle: @"Open Machine Configuration…"
                                    action: @selector (openConfiguration: )
                             keyEquivalent: @""];
  [item setTarget: self];
  [applicationMenu addItemWithTitle: @"Print Display…"
                             action: @selector (print: )
                      keyEquivalent: @"p"];
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
  _scaleMenu = [[NSMenu alloc] initWithTitle: @"View"];
  item = [[[NSMenuItem alloc] initWithTitle: @"View"
                                     action: NULL
                              keyEquivalent: @""] autorelease];
  [menu addItem: item];
  [menu setSubmenu: _scaleMenu forItem: item];
  {
    unsigned int i;
    static const unsigned int scales[] = { 100, 150, 200 };
    _screenScale =
        [[NSUserDefaults standardUserDefaults] integerForKey: @"ScreenScale"];
    if (_screenScale != 100 && _screenScale != 150 && _screenScale != 200)
      _screenScale = 100;
    for (i = 0; i < 3; i++)
      {
        item = [_scaleMenu
            addItemWithTitle: [NSString stringWithFormat: @"Screen Size %u%%",
                                                        scales[i]]
                      action: @selector (setScreenScale: )
               keyEquivalent: @""];
        [item setTarget: self];
        [item setTag: scales[i]];
      }
  }
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
  _display = [[DBDisplayView alloc] initWithFrame: NSMakeRect (0, 0, 832, 633)];
  _displayScroll =
      [[NSScrollView alloc] initWithFrame: NSMakeRect (12, 53, 832, 633)];
  [_displayScroll setHasHorizontalScroller: YES];
  [_displayScroll setHasVerticalScroller: YES];
  [_displayScroll setAutohidesScrollers: YES];
  [_displayScroll setBorderType: NSNoBorder];
  [_displayScroll setDocumentView: _display];
  [content addSubview: _displayScroll];
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
  [self applyScreenScale];
  [_window makeKeyAndOrderFront: nil];
  [_window makeFirstResponder: _display];
  _timer = [[NSTimer scheduledTimerWithTimeInterval: 0.01
                                             target: self
                                           selector: @selector (tick: )
                                           userInfo: nil
                                            repeats: YES] retain];
  _hubHost = [[[NSUserDefaults standardUserDefaults]
      stringForKey: @"NetworkHost"] copy];
  _hubPort =
      [[NSUserDefaults standardUserDefaults] integerForKey: @"NetworkPort"];
  if (_hubPort == 0)
    _hubPort = 3333;
  if (_pendingOpenPath != nil)
    {
      [self loadDisk: _pendingOpenPath];
      [_pendingOpenPath release];
      _pendingOpenPath = nil;
    }
  else if ([arguments count] > 1
           && ![[arguments objectAtIndex: 1] hasPrefix: @"-"])
    [self loadDisk: [arguments objectAtIndex: 1]];
  else
    {
      NSString *last =
          [[NSUserDefaults standardUserDefaults] stringForKey: @"LastHardDisk"];
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
  [_displayScroll release];
  [_scaleMenu release];
  [_status release];
  [_mediaStatus release];
  [_hubHost release];
  [_pendingOpenPath release];
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
- (void) openConfiguration: (id)sender
{
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  (void) sender;
  if ([panel runModalForTypes: [NSArray arrayWithObject: @"plist"]]
      == NSOKButton)
    {
      NSMutableDictionary *configuration =
          [NSMutableDictionary dictionaryWithContentsOfFile: [panel filename]];
      NSString *key,
          *base = [[panel filename] stringByDeletingLastPathComponent];
      NSArray *paths = [NSArray arrayWithObjects: @"Disk", @"Germ", nil];
      unsigned int i;
      if (configuration == nil
          || ![[NSArray arrayWithObjects: @"Draco", @"Duchess", nil]
              containsObject: [configuration objectForKey: @"Model"]])
        {
          NSRunAlertPanel (@"Invalid configuration",
                           @"Model must be Draco or Duchess.", @"OK", nil,
                           nil);
          return;
        }
      for (i = 0; i < [paths count]; i++)
        {
          NSString *path;
          key = [paths objectAtIndex: i];
          path = [configuration objectForKey: key];
          if (path != nil && ![path isAbsolutePath])
            [configuration setObject: [base stringByAppendingPathComponent: path]
                              forKey: key];
        }
      if ([configuration objectForKey: @"Disk"] == nil)
        {
          [panel setTitle: @"Select the workstation hard disk"];
          if ([panel
                  runModalForTypes: [NSArray arrayWithObjects: @"dsk", @"disk",
                                                             @"zdisk", nil]]
              != NSOKButton)
            return;
          [configuration setObject: [panel filename] forKey: @"Disk"];
        }
      if ([[configuration objectForKey: @"Model"] isEqual: @"Duchess"] &&
          [configuration objectForKey: @"Germ"] == nil)
        {
          [panel setTitle: @"Select the Duchess boot germ"];
          if ([panel runModalForTypes: [NSArray arrayWithObject: @"germ"]]
              != NSOKButton)
            return;
          [configuration setObject: [panel filename] forKey: @"Germ"];
        }
      if (![self mayDiscardDisk])
        return;
      NSDictionary *old = [[[NSUserDefaults standardUserDefaults]
          dictionaryForKey: @"MachineConfiguration"] retain];
      DBMachine *before = _machine;
      [[NSUserDefaults standardUserDefaults]
          setObject: configuration
             forKey: @"MachineConfiguration"];
      [self loadDisk: [configuration objectForKey: @"Disk"]];
      if (_machine == before)
        {
          if (old)
            [[NSUserDefaults standardUserDefaults]
                setObject: old
                   forKey: @"MachineConfiguration"];
          else
            [[NSUserDefaults standardUserDefaults]
                removeObjectForKey: @"MachineConfiguration"];
        }
      [old release];
    }
}
- (void) openDisk: (id)sender
{
  NSOpenPanel *panel = [NSOpenPanel openPanel];
  (void) sender;
  [panel setAllowsMultipleSelection: NO];
  [panel setDirectory: [[[NSBundle mainBundle] resourcePath]
                          stringByAppendingPathComponent: @"disks-6085"]];
  if ([panel runModalForTypes: [NSArray arrayWithObjects: @"zdisk", @"dsk",
                                                        @"disk", nil]]
          == NSOKButton
      && [self mayDiscardDisk])
    [self loadDisk: [panel filename]];
}
- (void) loadDisk: (NSString *)path
{
  NS_DURING
  NSDictionary *configuration = [[NSUserDefaults standardUserDefaults]
      dictionaryForKey: @"MachineConfiguration"];
  DBMachine *machine;
  if ([[configuration objectForKey: @"Model"] isEqual: @"Duchess"]
      && ![[[path pathExtension] lowercaseString] isEqual: @"zdisk"])
    {
      machine = [[DBDuchess alloc]
          initWithDisk: path
                 width: [[configuration objectForKey: @"Width"] unsignedIntValue]
                height: [[configuration objectForKey: @"Height"]
                           unsignedIntValue]
                 color: [[configuration objectForKey: @"Color"] boolValue]
           workingCopy: YES];
      NS_DURING
      [(DBDuchess *) machine
          bootWithGerm: [configuration objectForKey: @"Germ"]
              switches: [configuration objectForKey: @"Switches"]];
      NS_HANDLER
      [machine release];
      [localException raise];
      NS_ENDHANDLER
    }
  else
    machine = [[DBMachine alloc]
        initWithDisk: path
            switches: [configuration objectForKey: @"Switches"]
         workingCopy: YES
         largeScreen: [[configuration objectForKey: @"LargeScreen"] boolValue]];
  [_display setMachine: machine];
  [_machine release];
  _machine = machine;
  [self applyScreenScale];
  if (_hubHost != nil)
    [_machine setNetworkHost: _hubHost port: _hubPort];
  {
    NSString *floppyPath =
        [[NSUserDefaults standardUserDefaults] stringForKey: @"FloppyPath"];
    if (floppyPath &&
        [[NSFileManager defaultManager] fileExistsAtPath: floppyPath])
      [_machine insertFloppy: floppyPath
                    readOnly: [[NSUserDefaults standardUserDefaults]
                                 boolForKey: @"FloppyReadOnly"]];
  }
  _lastSave = [NSDate timeIntervalSinceReferenceDate];
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
  [protect setTitle: @"Write protect"];
  [panel setAccessoryView: protect];
  [panel setAllowsMultipleSelection: NO];
  if ([panel runModalForTypes: [NSArray arrayWithObjects: @"imd", @"dmk", @"img",
                                                        @"raw", nil]]
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
  [[NSUserDefaults standardUserDefaults] setObject: [panel filename]
                                            forKey: @"FloppyPath"];
  [[NSUserDefaults standardUserDefaults] setBool: [protect state] == NSOnState
                                          forKey: @"FloppyReadOnly"];
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
  [[NSUserDefaults standardUserDefaults] removeObjectForKey: @"FloppyPath"];
  [self refresh];
}
- (void) saveFloppy: (id)sender
{
  NSSavePanel *panel;
  (void) sender;
  if ([_machine floppy] == nil)
    return;
  panel = [NSSavePanel savePanel];
  [panel setAllowedFileTypes: [NSArray arrayWithObjects: @"imd", @"dmk", @"img",
                                                       @"raw", nil]];
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
      [[NSUserDefaults standardUserDefaults]
          removeObjectForKey: @"NetworkHost"];
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
      [[NSUserDefaults standardUserDefaults] setObject: name
                                                forKey: @"NetworkHost"];
      [[NSUserDefaults standardUserDefaults] setInteger: number
                                                 forKey: @"NetworkPort"];
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
  [panel setRequiredFileType: [[_machine disk] isKindOfClass: [DBGuamDisk class]]
                                 ? @"dsk"
                                 : @"zdisk"];
  if ([panel runModalForDirectory: nil
                             file: [[_machine disk]
                                      isKindOfClass: [DBGuamDisk class]]
                                      ? @"Session.dsk"
                                      : @"Session.zdisk"]
      != NSOKButton)
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
  if ([NSDate timeIntervalSinceReferenceDate] - _lastSave >= 30)
    {
      _lastSave = [NSDate timeIntervalSinceReferenceDate];
      [[_machine disk] saveWorkingCopy];
    }
  if ([_machine beepSerial] != _lastBeep)
    {
      _lastBeep = [_machine beepSerial];
      NSBeep ();
    }
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
- (void) setScreenScale: (id)sender
{
  unsigned int scale = [sender tag];
  if (scale != 100 && scale != 150 && scale != 200)
    return;
  _screenScale = scale;
  [[NSUserDefaults standardUserDefaults] setInteger: scale
                                             forKey: @"ScreenScale"];
  [self applyScreenScale];
}
- (void) applyScreenScale
{
  NSSize size = NSMakeSize (
      (_machine ? [_machine displayWidth] : 832) * _screenScale / 100.0,
      (_machine ? [_machine displayHeight] : 633) * _screenScale / 100.0);
  NSScreen *screen = [_window screen];
  NSRect oldFrame = [_window frame], frame, visible;
  NSSize contentSize;
  unsigned int i;
  if (screen == nil)
    screen = [NSScreen mainScreen];
  visible = [screen visibleFrame];
  frame = [_window
      frameRectForContentRect: NSMakeRect (0, 0, MAX (856, size.width + 24),
                                          size.height + 98)];
  frame.size.width = MIN (frame.size.width, visible.size.width);
  frame.size.height = MIN (frame.size.height, visible.size.height);
  frame.origin.x
      = MAX (NSMinX (visible),
             MIN (oldFrame.origin.x, NSMaxX (visible) - frame.size.width));
  frame.origin.y
      = MAX (NSMinY (visible), MIN (NSMaxY (oldFrame) - frame.size.height,
                                    NSMaxY (visible) - frame.size.height));
  [_window setFrame: frame display: YES];
  contentSize = [[_window contentView] bounds].size;
  [_display setFrameSize: size];
  [_displayScroll setFrame: NSMakeRect (12, 53, MAX (1, contentSize.width - 24),
                                       MAX (1, contentSize.height - 98))];
  /* Begin at the top left even when a scaled document exceeds the viewport. */
  [_display
      scrollPoint: NSMakePoint (
                      0, MAX (0, size.height -
                                     [[_displayScroll contentView] bounds]
                                         .size.height))];
  for (i = 0; i < [_scaleMenu numberOfItems]; i++)
    {
      NSMenuItem *item = [_scaleMenu itemAtIndex: i];
      [item setState: [item tag] == _screenScale ? NSOnState : NSOffState];
    }
  [[_display window] invalidateCursorRectsForView: _display];
  [_display setNeedsDisplay: YES];
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
