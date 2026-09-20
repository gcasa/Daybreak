# Daybreak

Daybreak is an Objective-C port of the shared Mesa execution engine in
[Dr. Hans-Walter Latz's Dwarf](https://github.com/devhawala/dwarf).
It uses GNUstep Base, Objective-C 1.0 syntax, explicit retain/release,
and GNU-style C formatting. No Java runtime is needed to build or run it.

**This is an initial processor-core implementation, not a complete Dwarf
workstation emulator. It does not yet boot ViewPoint, XDE, or GlobalView.**
The device agents, 6085 I/O processor, control transfers, process scheduler,
block transfers, and graphical interface still need porting. See
[the coverage and porting notes](Documentation/PORTING.md).

The implemented engine has independent processor instances, a 14-word stack,
16-bit words, 32-bit pointers, virtual-memory mapping and protection, and
261 instruction implementations (including old/new global-frame variants).
Unsupported instructions raise descriptive exceptions.

## Build and run

On a GNUstep system, install GNUstep Base development headers, gnustep-make,
and an Objective-C compiler. On Debian/Ubuntu, the packages are
`libgnustep-base-dev`, `gnustep-make`, and `gobjc`.

```sh
make -f Makefile CC=gcc
./build/daybreak --demo
make -f Makefile CC=gcc check
```

The demo executes `7 * 6 + 1`, producing stack word `002b` (43).
The native GNUstep make build is also available:

```sh
make -f GNUmakefile
./obj/daybreak --demo
```

For development on macOS without GNUstep, `make -f Makefile` uses Apple
Foundation with ARC disabled. All project runtime APIs are available in
GNUstep Base; Apple Foundation is only an alternate development build.

Execute a raw, even-length, big-endian Mesa bytecode image:

```sh
./build/daybreak --steps 5 --base 0x30000 --pc 0 program.bin
```

`--post40` selects the changed-chapters global-frame instructions. PC is a
byte offset; base is a word address. The runner supplies 4 MiB of RAM and
32 MiB of virtual address space. It initially maps installed RAM directly;
virtual page zero always traps. This raw format is **not** a germ, disk, or
compressed `.zdisk` file. Execution is bounded by the requested instruction
count and reports errors with a nonzero exit status.

## Documentation

Public headers contain autogsdoc comments, including ownership, addressing,
error behavior, and limitations. With GNUstep's `autogsdoc` installed:

```sh
make -f Makefile docs
```

HTML and GSDoc XML for public and internal headers are written to
`Documentation/API/`. The public entry
points are `Source/DBMemory.h` and `Source/DBProcessor.h`.

## Validation

```sh
make -f Makefile check
make -f Makefile sanitize
make -f Makefile reference-check DWARF=../dwarf
```

`check` runs memory, stack, opcode, fault/retry, and instruction-mode tests,
the executable demo, and a guard against Objective-C 2.0 syntax.
`sanitize` rebuilds with AddressSanitizer and UndefinedBehaviorSanitizer;
select an appropriate compiler with `CC=...`.

`reference-check` additionally requires Python 3 and a JDK. It compiles an
unmodified local Dwarf checkout and compares thousands of successful
arithmetic and jump executions, including all active and inactive stack
slots. It does not claim full instruction, fault-handler, or OS equivalence.
No Java sources or Xerox disk images are redistributed here.

Detailed results and limitations are recorded in
[the validation notes](Documentation/VALIDATION.md).

The `.github/workflows/gnustep.yml` workflow builds with GCC and the GNU
Objective-C runtime and generates documentation on Ubuntu.

## Source provenance

The reference checkout used for this port is Dwarf commit
`c264af5e37f89d7aa0eec968aa23818bf5a89837`.
Its BSD 3-Clause license and original copyright are retained in `COPYING`.
`Tools/port-instructions.py` reproduces the straight-line instruction bodies
from a local reference checkout; generated Objective-C is checked in.
After regeneration, run `Tools/format-source.py` with `clang-format`.
