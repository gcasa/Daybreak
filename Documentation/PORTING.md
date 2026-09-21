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
| Transfers/graphics | DBBlocks: restartable word/byte transfers, comparisons/checksum, monochrome BITBLT/COLORBLT/BITBLTX |
| Boot | DBMachine: Draco memory map, germ extraction, boot request, processor IOP commands |
| Disk | DBDisk and DBMachine: compressed disk/delta loading, labels/data, asynchronous guest completion protocol, export |
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

* The supported boot target is small-screen, monochrome Draco/6085. Duchess
  device agents, large-screen/color configurations and other OS images have
  not been ported or validated.
* Disk changes are private in-memory working copies. Save Copy exports a
  complete compressed image atomically, refuses the input path, and refuses
  destinations with a conflicting delta file. Hardware formatting is not
  implemented. Guest label/data verification reports device errors.
* Networking reports an offline interface; there is no host network bridge.
  Floppy hardware reports no medium; queued floppy media operations are not
  implemented. Beep notifications produce no host audio.
* The GUI uses a host cursor and a basic US keyboard map. Guest cursor shapes,
  configurable key mappings, clipboard, printing and full Dwarf UI features
  remain outside this implementation.
* TRAPZBLT and VMFIND are not implemented. Unsupported instructions use guest
  software trap handlers where available, including Dwarf's TXTBLT and
  floating-point fallback cases. This is not full opcode equivalence.

The reference machine ID matches the supplied ViewPoint configuration.
The guest's calendar and software configuration can still require adjustment
inside the OS. Header documentation describes individual API contracts.
