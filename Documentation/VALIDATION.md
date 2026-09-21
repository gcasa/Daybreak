# Validation

Validated on 2026-09-20 against Dwarf commit
`c264af5e37f89d7aa0eec968aa23818bf5a89837`.

* 358 engine checks cover memory, maps, protection, stack limits, arithmetic,
  jumps, instruction modes and diagnostic fault retry.
* 77 system checks cover frame allocation, old/new calls and returns, guest
  traps, priority queues, condition wakeup, preempted state vectors,
  restartable word/bitmap transfers, compressed disk loading, safe export,
  preservation of input images and rejection of truncated data.
* 155 device checks cover mixed-size/compressed IMD, FM DMK, media export
  and preservation of originals, format validation, guest read/write/deleted
  data/read-ID operations, no-media/write-protect/DMA errors and interrupts.
  A local TCP peer exercises split/coalesced NetHub framing, guest transmit
  and receive queues, odd-byte buffers, truncation, reset, queue bounds,
  malformed frames, disconnect and reconnect. Fixtures contain no Xerox code.
* 62 additional feature checks cover Guam memory/display mapping (including
  small trailing MAPDISPLAY blocks), disk read/write/format, raw disk delta
  import, palettes, cursor, keyboard, beep, VMFIND, restartable trapezoid
  transfers, monochrome-to-color expansion, XNS time and loopback, raw/DMK
  media round trips, synthetic SCP MFM decoding and truncated-image rejection.
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
  user login is claimed. The updated XDE GUI was also checked connecting to
  a local NetHub-protocol test listener, emitting guest Ethernet frames, and
  inserting/ejecting a synthetic IMD floppy.
* AddressSanitizer and UndefinedBehaviorSanitizer pass all 652 engine, system, device
  and feature checks with Homebrew LLVM and Apple Foundation, ARC disabled.
  The previous OS boot tests also passed sanitizers.
* Autogsdoc generates all thirteen header documents; their XML validates against
  the GSDoc 1.0.4 DTD. The Objective-C 1.0 syntax guard passes.
* Both disks also boot with GNUstep Base. The native GNUstep GUI application
  compiles and links against GNUstep GUI 0.32.0.

GNUstep checks ran on Linux ARM64 (Debian 12, GCC and the GNU Objective-C
runtime, GNUstep Base 1.28 / GUI 0.29 / Cairo under Xvfb), as well as the
previous isolated GNUstep Base 1.31.1 build on macOS. The GUI now handles
GNUstep launch-file delivery before window creation. The CI workflow includes
a GUI startup smoke test checking the disk-named workstation window. A
90-second Linux GUI run reached MP 8000 and its rendered ViewPoint logged-out
screen was visually checked (`build/linux-validation/linux-gui.png`).

Additional native boot runs reached:

| Configuration | Result |
| --- | --- |
| Draco XDE, 1152 × 861 | MP 990, visually checked desktop |
| Duchess Dawn/Tajo, 960 × 720 monochrome | MP 990, visually checked Tajo desktop |
| Duchess Dawn/Tajo, 1152 × 900 indexed color | MP 990, visually checked desktop; local XNS packets exchanged |

The Dawn files were separately downloaded from the
[official Dawn distribution](https://www.woodward.org/mps/) into ignored
`build/duchess-media/` for validation, not copied into application resources.
Only the germ and disk were used; Dawn implementation source was not ported.
The original sibling Dwarf checkout contains Draco seed disks and an empty
raw floppy, but no Duchess germ/disk or real Xerox floppy images.

No authenticated ViewPoint/Tajo user session or external XNS filer/login
interoperability is claimed. The color guest desktop uses monochrome palette
entries; synthetic checks additionally verify non-gray RGB palette values and
color transfer mapping. TAP opens compile on Linux/macOS but an external
host bridge has not been exercised. Real Xerox floppy images remain untested;
media tests use generated fixtures. SCP is MFM sector recovery, not proof of
flux-timing equivalence. The remaining implementation gaps are recorded in
[port status](PORTING.md).
