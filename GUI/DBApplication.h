/** <title>Daybreak desktop interface</title>
    <author name="Daybreak contributors"></author> */
#ifndef DAYBREAK_APPLICATION_H
#define DAYBREAK_APPLICATION_H
#import <AppKit/AppKit.h>
#import "DBMachine.h"
/** Display and Level V input surface. Retains its machine and releases all
    guest keys when focus is lost. All access occurs on the application thread.
 */
@interface DBDisplayView : NSView
{
  DBMachine *_machine;
  NSMutableDictionary *_pressedKeys;
}
/** Replace the displayed machine, releasing keys on the old machine. */
- (void) setMachine: (DBMachine *)machine;
/** Release guest input when the application loses focus. */
- (void) releaseInput;
/** Convert a host keyboard event into a guest key press or release. */
- (void) keyEvent: (NSEvent *)event pressed: (BOOL)pressed;
/** Release a guest key after a minimum pulse visible to the guest scanner. */
- (void) releaseKey: (NSNumber *)key;
/** Convert window mouse coordinates into guest display coordinates. */
- (void) updateMouse: (NSEvent *)event;
@end

/** Application controller. Uses bounded execution slices on the UI thread,
    avoiding races between emulation, display refresh and device input. */
@interface DBApplication : NSObject
{
  NSWindow *_window;
  DBDisplayView *_display;
  NSTextField *_status, *_mediaStatus;
  NSString *_hubHost;
  unsigned int _hubPort;
  NSButton *_pauseButton;
  NSTimer *_timer;
  DBMachine *_machine;
  BOOL _paused;
}
/** Route window closing through working-disk saving and floppy checks. */
- (BOOL) windowShouldClose: (id)sender;
/** Create the window and menus, then open the command-line or last working disk. */
- (void) applicationDidFinishLaunching: (NSNotification *)notification;
/** Release all guest input when the application loses focus. */
- (void) applicationDidResignActive: (NSNotification *)notification;
/** Release input when the main window loses key status. */
- (void) windowDidResignKey: (NSNotification *)notification;
/** Terminate after the emulator window closes. */
- (BOOL) applicationShouldTerminateAfterLastWindowClosed:
    (NSApplication *)application;
/** Offer a disk picker for XDE, ViewPoint or another Draco image. */
- (void) openDisk: (id)sender;
/** Import or resume a Library working disk, replacing the machine after loading.
 */
- (void) loadDisk: (NSString *)path;
/** Choose and insert IMD/DMK media, with an optional write-protect switch. */
- (void) insertFloppy: (id)sender;
/** Eject media, checking unsaved changes. */
- (void) ejectFloppy: (id)sender;
/** Export a modified floppy as a separate IMD image. */
- (void) saveFloppy: (id)sender;
/** Configure the NetHub TCP endpoint or disconnect. */
- (void) configureNetwork: (id)sender;
/** Finish the modal NetHub configuration panel using the sender tag. */
- (void) finishNetworkPanel: (id)sender;
/** Check floppy changes before ejecting or replacing media. */
- (BOOL) mayDiscardFloppy;
/** Toggle instruction execution. */
- (void) pause: (id)sender;
/** Execute one instruction while paused. */
- (void) step: (id)sender;
/** Export the working disk to a separate .zdisk image. */
- (void) saveDisk: (id)sender;
/** Run one bounded instruction slice and update the display/status. */
- (void) tick: (NSTimer *)timer;
/** Refresh the processor status and framebuffer. */
- (void) refresh;
/** Stop execution and show the actual exception. */
- (void) reportException: (NSException *)exception;
/** Save the working hard disk and check floppy changes before replacing or quitting. */
- (BOOL) mayDiscardDisk;
/** Save the working disk on termination; cancel termination if saving fails. */
- (NSApplicationTerminateReply) applicationShouldTerminate:
    (NSApplication *)application;
@end
#endif
