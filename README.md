# Daybreak

Daybreak is an Objective-C implementation of the Mesa engine and Draco/6085
workstation in [Dwarf](https://github.com/devhawala/dwarf). It uses GNUstep
Base and GUI, Objective-C 1.0 syntax, manual retain/release, GNU-style
formatting, and autogsdoc header documentation. No Java runtime is required.

The included Dwarf **XDE 5.0 and ViewPoint 2.0.5 disk images boot**: XDE to its
desktop (MP 990), ViewPoint to its logged-out screen and login form (MP 8000).
Control transfers, guest traps and faults, priority scheduling, synchronization,
interrupts, restartable block transfers, and monochrome graphics are implemented.
NetHub networking and IMD/DMK floppy media are supported. Duchess agents are
not implemented.
See [port status](Documentation/PORTING.md) for the precise scope.

## Build and run

On Debian/Ubuntu install `gobjc`, `gnustep-make`, `libgnustep-base-dev`,
`libgnustep-gui-dev`, a GNUstep GUI backend, and `zlib1g-dev`.
Load your GNUstep environment before building with its native makefiles.

```sh
make -f Makefile CC=gcc check
make -f GNUmakefile.gui
openapp ./Daybreak.app ../dwarf/disks-6085/xde5.0.zdisk
```

The GUI also has an Open Disk button. It provides an 832 × 633 monochrome
screen, keyboard and three-button mouse input, Pause/Resume, single Step,
Save Copy, floppy insert/eject, and a NetHub connection panel. Disk changes stay in memory until explicitly exported to a
new `.zdisk`; the input disk and its optional `.zdelta` are never overwritten.
Booting the OS itself changes its working disk, so save a copy before closing
if you want those changes. Export while paused for a consistent emulator state;
as on physical hardware, guest buffers must be flushed before a clean shutdown.

F1–F8 map to Help, Props, Copy, Move, Find, Open, Undo, Again. Escape is Stop,
Control is Special, and the mouse buttons are Point, Adjust, Menu. This initial
keyboard map follows a US keyboard. The host pointer is used for the cursor.

On macOS without GNUstep, `make -f Makefile gui` builds
`build/Daybreak.app` with Apple AppKit and ARC disabled. Launch with:

```sh
open build/Daybreak.app --args ../dwarf/disks-6085/vp2.0.5.zdisk
```

The command-line build supports bounded boot runs and PBM framebuffer exports:

```sh
make -f Makefile
./build/daybreak --disk ../dwarf/disks-6085/xde5.0.zdisk --seconds 30 \
  --snapshot build/xde.pbm
./build/daybreak --disk ../dwarf/disks-6085/vp2.0.5.zdisk --seconds 30 \
  --save-copy build/session.zdisk
./build/daybreak --demo
```

`--switches STRING` overrides the default germ boot switches. `--steps N`
may replace `--seconds N`; restartable block transfers count their individual
execution units. The raw bytecode runner remains available:
`./build/daybreak --steps 5 --base 0x30000 --pc 0 program.bin`.
`--post40` selects changed-chapters instructions for raw images. Raw files are
big-endian words, not compressed disks or standalone boot germs.

## Networking and floppy media

Use **Network…** to connect to a Dwarf-compatible NetHub (TCP port 3333 by
convention), or configure it at launch in the command-line runner:

```sh
./build/daybreak --disk ../dwarf/disks-6085/xde5.0.zdisk --seconds 60 \
  --hub localhost --hub-port 3333 --floppy /path/to/disk.imd
```

Networking is disabled until an endpoint is supplied. The transport handles
partial TCP frames, bounded queues, disconnects and automatic reconnects;
the status line shows connection state and packet counts. This carries the
guest's Ethernet/XNS traffic to NetHub. XNS servers and the hub run separately;
Daybreak does not provide a filer, Internet gateway, or internal time server.
For multiple workstations, assign distinct unicast IDs before boot with
`--host-id 1000FE31AB22`. The default `1000FE31AB21` preserves the supplied
ViewPoint configuration; changing it can affect guest software configuration.

Use **Floppy…** to insert `.imd` or `.dmk` media and **Eject** to remove it.
The file chooser's options include write protection. DMK is always protected;
IMD can be read, written, and formatted by the guest. **Daybreak → Save Floppy
Copy…** exports a complete `.imd` copy without changing the input file.
The application checks unsaved floppy changes before replacement or exit.
For the command-line runner, use `--floppy-read-only` and
`--save-floppy /path/to/copy.imd` as needed. Floppy selection and hub settings
apply to the current application session.

The media reader handles mixed track sizes, ImageDisk compression, logical
sector maps, deleted/error sector flags, and DMK FM/MFM records. Malformed
images are rejected. This is sector-level emulation, not a flux/timing model;
raw `.img` files and writing DMK images in place are not supported.

## Documentation and validation

```sh
make -f Makefile docs
make -f Makefile check
make -f Makefile reference-check DWARF=../dwarf
make -f Makefile boot-check DWARF=../dwarf
make -f Makefile sanitize CC=clang
```

Autogsdoc writes HTML and GSDoc XML from all engine and GUI headers to
`Documentation/API/`. Start with `DBMachine.h`, `DBProcessor.h`, and
`DBMemory.h`. The reference comparison requires a JDK and a local Dwarf
checkout; boot checks additionally require the two disks shown above. They
keep disk writes in memory and export screenshots to `build/`.
Xerox images are not redistributed. Detailed results are in
[validation notes](Documentation/VALIDATION.md).

## Source provenance

The reference is Dwarf commit `c264af5e37f89d7aa0eec968aa23818bf5a89837`.
Its BSD 3-Clause license and original copyright are retained in `COPYING`.
`Tools/port-instructions.py` regenerates straight-line instruction bodies;
`Tools/format-source.py` applies the GNU layout and Objective-C selector style.
`Tools/DumpIO.java`, compiled against the reference classes, dumps initial
6085 IOP words to its first argument and field descriptions to stdout; these
are the source of the annotated constants in `DBIOInitial.inc`.
