# Port status and architecture

Daybreak boots the Draco/6085 XDE 5.0 and ViewPoint 2.0.5 disks supplied in
the reference checkout. It is a native implementation, not a Java wrapper.

| Component | Implementation |
| --- | --- |
| Memory | DBMemory: word/byte access, page maps, protection, physical device access |
| Processor | DBProcessor: per-instance registers and stack, bounded execution, old/new instruction sets |
| Scalar instructions | DBInstructions: generated arithmetic, stack, jumps and assignments |
| Control | DBControl: frame allocation, old/new global frames, calls/returns, transfer traps, guest trap dispatch, state vectors |
| Processes | DBProcesses: priority queues, preemption, monitors, conditions, interrupts, timeouts and fault queues |
| Transfers/graphics | DBBlocks: restartable word/byte transfers, comparisons/checksum, monochrome/color BITBLT/COLORBLT/BITBLTX and TRAPZBLT |
| Boot | DBMachine: Draco memory map, germ extraction, boot request, processor IOP commands; DBDuchess: Guam map, germ loader and agents |
| Disk | DBDisk and DBMachine: compressed disk/delta loading, labels/data, asynchronous guest completion protocol, export |
| Networking | DBNetwork and DBDevices: nonblocking NetHub TCP framing, queued receive buffers, send/receive completion and interrupts, reset/reconnect |
| Floppy | DBFloppy and DBDevices: IMD/DMK/raw/SCP MFM parsing, media changes, read/write/deleted data, read-ID and track format, write protection, DMA errors and export |
| Display/input | DBMachine and DBApplication: framebuffer, retrace, keyboard/mouse, native AppKit window and controls |

## Execution and ownership

Memory addresses are Mesa words. External words are big-endian; Mesa double
words store the low word first. The machine has 4 MiB real and 32 MiB virtual
memory, with the Draco I/O map and monochrome display bank. The code PC and
short pointers wrap at 16 bits.

Each processor owns its register state, interrupt mask, timer, and suspended
bitmap operations. The processor retains memory; DBMachine owns its working
disk. Borrowed register and memory accessors do not transfer ownership.
The GUI executes bounded slices on its main thread, serializing input,
display, disk access, and emulation. Instances require external serialization.

Plain DBProcessor defaults to diagnostic exception mode: failed instructions
restore registers/stack but do not roll back memory writes. DBMachine enables
guest traps: failures enter Mesa trap or process-fault handlers. A page fault
during trap entry itself is delivered through the process fault machinery.

Word and byte transfers execute one unit per step; bitmap operations execute
one scanline per step. Continuations preserve completed work across faults
and preemption. This intentionally changes instruction counts relative to
Dwarf without repeating completed writes. Interrupt and timer checks occur
between execution units. The monotonic interval timer is independent of the
host wall clock used for the guest calendar.

## Device scope and remaining work

Implemented additions include Duchess disk/floppy/network/keyboard/mouse/
processor/display/beep agents, raw Pilot disks with delta import, Draco large
screens, indexed-color rendering and palettes, VMFIND, TRAPZBLT, hardware disk
format commands, writable DMK export with CRC validation, raw and SCP MFM
floppy import, Draco scan operations, TAP transport and local XNS time/echo.
GUI profiles select machine and display settings. Cursor shapes, configurable
key mappings, clipboard typing/screen copying, screen printing, host beeps,
persistent media/network settings and periodic disk checkpoints are present.

Remaining limitations are explicit:

* XNS filer, authentication/clearinghouse services and external login/filer
  interoperability are not implemented or validated by this change. NetHub
  and external services can be selected separately.
* Clipboard copy captures the display, not guest-selected text; printing is
  host framebuffer printing, not a guest Interpress printer agent. Serial,
  parallel, stream/file-boot and other unused Guam agents are unavailable.
* SCP supports MFM decoding into sectors. FM/GCR flux, weak bits, flux export
  and hardware rotational timing are not emulated. Real Xerox floppy media
  has not been validated. Disk formatting is logical sector formatting.
* Checkpoints preserve the prior disk save, not CPU/RAM state. Recovery is
  manual by opening the `.previous` image; consistency still depends on guest
  filesystem buffers having been flushed.
* TXTBLT and floating-point fallback instructions still enter guest software
  trap handlers where available. Full opcode/device equivalence is not claimed.
* Dawn/Tajo boots in Duchess monochrome and color configurations, but this does
  not validate GlobalView or other OS releases, authenticated sessions, every
  palette/graphics operation or every media/controller combination.

The reference machine ID matches the supplied ViewPoint configuration.
Header documentation describes individual API contracts.
