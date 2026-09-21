# Validation

Validated on 2026-09-20 against Dwarf commit
`c264af5e37f89d7aa0eec968aa23818bf5a89837`.

* 358 engine checks cover memory, maps, protection, stack limits, arithmetic,
  jumps, instruction modes and diagnostic fault retry.
* 60 system checks cover frame allocation, old/new calls and returns, guest
  traps, priority queues, condition wakeup, preempted state vectors,
  restartable word/bitmap transfers, compressed disk loading, safe export,
  preservation of input images and rejection of truncated data.
* The Java differential harness compares 5,837 successful arithmetic/jump
  executions, including PC and all stack slots. It does not prove equivalence
  of every opcode or guest trap path.
* The automated boot test loads each original disk into a private working
  copy, waits for its ready maintenance code and enabled display, requires
  at least 19,000 disk reads to exclude early boot screens, checks a nonempty
  framebuffer, and exports a PBM. XDE reaches MP 990 with 20,129
  disk reads in the Apple Foundation run. ViewPoint reaches MP 8000 and
  receives a Space key pulse,
  exercising the transition from its logged-out screen to the login form.
* The Apple AppKit GUI was visually checked with ViewPoint: upright display,
  login form after keyboard input, and native window controls. No ViewPoint
  user login or network session is claimed.
* AddressSanitizer and UndefinedBehaviorSanitizer pass the 418 engine and
  system checks and both OS boot tests with Homebrew LLVM and Apple
  Foundation, ARC disabled.
* Autogsdoc generates all ten header documents; their XML validates against
  the GSDoc 1.0.4 DTD. The Objective-C 1.0 syntax guard passes.
* Both disks also boot with GNUstep Base. The native GNUstep GUI application
  compiles and links against GNUstep GUI 0.32.0.

GNUstep checks use an isolated GCC 16 / GNU Objective-C runtime / GNUstep
Base 1.31.1 build on macOS ARM64, with host-toolchain compatibility fixes in
that temporary dependency build. The Ubuntu/GCC workflow is included but
has not been executed here. GUI behavior on a GNUstep display backend still
needs testing; the interactive run used Apple's AppKit fallback.

The tests establish boot and the exercised paths, not complete Xerox OS or
peripheral compatibility. Networking, floppy media, Duchess hardware, and
color display remain outside the validated scope.
