# Daybreak

Daybreak is an Objective-C implementation of the Mesa engine and Draco/6085
workstation in [Dwarf](https://github.com/devhawala/dwarf). It uses GNUstep
Base and GUI, Objective-C 1.0 syntax, manual retain/release, GNU-style
formatting, and autogsdoc header documentation. No Java runtime is required.

The included Dwarf **XDE 5.0 and ViewPoint 2.0.5 disk images boot**: XDE to its
desktop (MP 990), ViewPoint to its logged-out screen and login form (MP 8000).
Control transfers, guest traps and faults, priority scheduling, synchronization,
interrupts, restartable block transfers, and monochrome graphics are implemented.
Networking remains offline; floppy media and Duchess agents are not implemented.
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
and Save Copy. Disk changes stay in memory until explicitly exported to a
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
