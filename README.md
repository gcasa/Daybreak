# Daybreak

Daybreak is an Objective-C implementation of the Mesa engine and Draco/6085
and Duchess/Guam workstations in [Dwarf](https://github.com/devhawala/dwarf). It uses GNUstep
Base and GUI, Objective-C 1.0 syntax, manual retain/release, GNU-style
formatting, and autogsdoc header documentation. No Java runtime is required.

The included Dwarf **XDE 5.0 and ViewPoint 2.0.5 disk images boot**: XDE to its
desktop (MP 990), ViewPoint to its logged-out screen and login form (MP 8000).
Control transfers, guest traps and faults, priority scheduling, synchronization,
interrupts, restartable block transfers, and monochrome graphics are implemented.
Duchess boots the separately supplied Dawn/Tajo disk. Large monochrome and
8-bit indexed-color display configurations are available. Networking supports
NetHub, TAP, and local XNS time/echo; floppy formats include IMD, DMK, raw and
SCP MFM.
See [port status](Documentation/PORTING.md) for the precise scope.

## Build and run

On Debian/Ubuntu install `gobjc`, `gnustep-make`, `libgnustep-base-dev`,
`libgnustep-gui-dev`, a GNUstep GUI backend, and `zlib1g-dev`.
Load your GNUstep environment before building with its native makefiles.

```sh
make -f Makefile CC=gcc check
make -f GNUmakefile.gui
openapp ./Daybreak.app disks-6085/xde5.0.zdisk
```

The GUI provides keyboard and three-button mouse input, guest cursor shapes,
Pause/Resume, single Step, Save Copy, floppy insert/eject, and a network panel.
Use **Open Machine Configuration…** with a plist from `Configurations/` to
select Draco large-screen mode or Duchess monochrome/color. Duchess profiles
prompt for a compatible raw hard disk and germ. Paths in profiles are relative
to the profile directory. The original Dwarf checkout contains Draco disks,
not Duchess boot media.

Duchess dimensions must be multiples of 16 horizontally, up to 2048 × 1536.
The color mode is 8-bit indexed color. `Duchess-Color.plist` uses 1152 × 900;
Draco supports 832 × 633 and 1152 × 861 monochrome. Use **View → Screen Size 100%, 150%, or 200%** to select native size,
1.5×, or 2× magnification. The selection is remembered. The window grows to
fit the display where possible; scrollbars provide access when the enlarged
screen exceeds the host display. Mouse input follows the selected scale.

The three original disk images are included in `disks-6085/` and in application
bundle resources, along with Dwarf's original image notes. Opening an original
imports its contents (including an optional `.zdelta`) into a separate writable
hard disk. Originals are never modified. Working disks live under:

- macOS: `~/Library/Application Support/Daybreak/Hard Disks/`
- GNUstep: `~/GNUstep/Library/Daybreak/Hard Disks/`

Each import has its own directory, so selecting images with the same filename
cannot overwrite an existing working disk. Opening a managed disk resumes it;
selecting an original again creates a fresh copy. The GUI remembers the last
working disk and reopens it on launch. Changes are saved atomically every 30 seconds, when replacing
the disk, or when quitting normally; a save failure keeps the current session open.
The command-line `--disk` mode also imports or resumes a working disk, prints its
location, and saves it on successful completion. The previous save is retained beside the working disk as
`NAME.previous.EXT`; open that file to import a recovery copy. This is disk
checkpointing, not a saved CPU/RAM session. Abrupt termination can lose
changes since the last save. Save Copy exports a separate image without clearing
pending changes to the managed disk. As on physical hardware, flush guest buffers
before shutting down for a consistent filesystem.

F1–F8 map to Help, Props, Copy, Move, Find, Open, Undo, Again. Escape is Stop,
Control is Special, and the mouse buttons are Point, Adjust, Menu. This initial
keyboard map follows a US keyboard. Guest cursor shapes replace the host arrow. The `KeyboardMap` defaults
dictionary maps decimal host key codes to Mesa key numbers (0–111).
Copy exports the screen image; Paste types supported US keyboard text into
the guest; Print Display prints the framebuffer. These are host conveniences,
not guest text-selection or Interpress printer integration. Beeps use host audio.

On macOS without GNUstep, `make -f Makefile gui` builds
`build/Daybreak.app` with Apple AppKit and ARC disabled. Launch with:

```sh
open build/Daybreak.app --args disks-6085/vp2.0.5.zdisk
```

The command-line build supports bounded boot runs and PPM RGB framebuffer exports:

```sh
make -f Makefile
./build/daybreak --disk disks-6085/xde5.0.zdisk --seconds 30 \
  --snapshot build/xde.ppm
./build/daybreak --disk disks-6085/vp2.0.5.zdisk --seconds 30 \
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
./build/daybreak --disk disks-6085/xde5.0.zdisk --seconds 60 \
  --hub localhost --hub-port 3333 --floppy /path/to/disk.imd
```

Networking is disabled until an endpoint is supplied. The transport handles
partial TCP frames, bounded queues, disconnects and automatic reconnects;
the status line shows connection state and packet counts. This carries the
guest's Ethernet/XNS traffic to NetHub. XNS servers and the hub run separately;
Use endpoint `local` for a built-in XNS time/echo responder. Endpoint
`tap:NAME` opens a Linux TAP interface; `tap:/dev/tapN` opens an existing
macOS TAP device. Host interface permissions and bridge configuration remain
administrator responsibilities. Daybreak does not provide an XNS filer,
authentication/clearinghouse server, or Internet gateway.
For multiple workstations, assign distinct unicast IDs before boot with
`--host-id 1000FE31AB22`. The default `1000FE31AB21` preserves the supplied
ViewPoint configuration; changing it can affect guest software configuration.

Use **Floppy…** to insert `.imd`, `.dmk`, `.img`, `.raw`, or `.scp` media.
Originals are preserved. Explicit write protection and DMK/SCP protection
flags are honored. Save Floppy Copy exports IMD, regenerated MFM DMK, or
standard 512-byte-sector raw images; raw export rejects lossy conversions.
SCP import decodes MFM sectors and CRCs; flux export, FM/GCR flux decoding,
weak-bit and rotational timing emulation remain unsupported.

The GUI remembers the floppy path, write protection, and network endpoint.
Changed floppy contents still require explicit export before replacement or
exit. CLI options include `--floppy-read-only` and `--save-floppy COPY.imd`.
The controllers support sector read/write/deleted data, formatting and Draco
FDC scan operations. These are sector-level emulations.

Example Duchess boot with separately acquired media:

```sh
./build/daybreak --duchess --germ /path/to/Dawn.germ \
  --color --width 1152 --height 900 --hub local \
  --seconds 30 --snapshot build/duchess.ppm /path/to/Dawn.dsk
```

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
The Draco seed disks are included with their original notes; separate Dawn
test downloads are not bundled. Detailed results are in
[validation notes](Documentation/VALIDATION.md).

## Source provenance

The reference is Dwarf commit `c264af5e37f89d7aa0eec968aa23818bf5a89837`.
Its BSD 3-Clause license and original copyright are retained in `COPYING`.
`Tools/port-instructions.py` regenerates straight-line instruction bodies;
`Tools/format-source.py` applies the GNU layout and Objective-C selector style.
`Tools/DumpIO.java`, compiled against the reference classes, dumps initial
6085 IOP words to its first argument and field descriptions to stdout; these
are the source of the annotated constants in `DBIOInitial.inc`.
