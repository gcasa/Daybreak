# Port status and architecture

This release implements a testable Mesa execution core. A complete native
workstation emulator remains unfinished. The project deliberately reports
unimplemented instructions rather than pretending to boot an OS.

| Dwarf component | Objective-C implementation | Status |
| --- | --- | --- |
| `Mem` | `DBMemory` | Word/byte/double-word access, fields, page maps, access flags and protection; no workstation-specific initial mapping or display RAM |
| `Cpu` | `DBProcessor` | Per-instance registers, evaluation stack, instruction fetch and bounded execution; host-reported exceptions |
| `Opcodes` | `DBInstructionDispatch.inc` | Explicit primary and ESC/ESCL dispatch with old/new instruction-set selection |
| Chapter 3 | `DBInstructions` | SM, SMF, GMF, LP, ROB, WOB, RRMDS, WRMDS |
| Chapter 5 | `DBInstructions` | Integer/stack operations and the six floating-point operations implemented by Dwarf; unsupported floating-point operations trap |
| Chapter 6 | `DBInstructions` | All jump instructions |
| Chapter 7 | `DBInstructions` | All assignments, including both global-frame variants |
| Chapter 8 | — | Block, byte and bit transfers pending |
| Chapter 9 / `Xfer` | — | Frame allocation and control transfers pending |
| Chapter 10 / `Processes` | — | Scheduling, synchronization, interrupts and timers pending |
| `InitialMesaMicrocode` | — | Germ loading and boot requests pending |
| `agents` | — | Duchess disk, floppy, display, keyboard, mouse, network and other devices pending |
| `iop6085` | — | Draco hardware and I/O processor pending |
| Swing UI | — | GNUstep GUI frontend pending |

There are 261 implemented instruction bodies and fewer distinct opcode slots
because PrincOps 4.0 and post-4.0 share slot numbers for different global-frame
instructions. `supportsOpcode:escape:` queries availability in the selected
mode. The ESC and ESCL prefix bytes are dispatch mechanisms, not standalone
instruction implementations.

## Representation and ownership

* Mesa words use `uint16_t`; addresses and double words use `uint32_t`.
* A word's high byte is stored first in an external byte stream. A double
  word's low word comes first in memory and on the evaluation stack.
* Code PC wraps at 16 bits; code-word offsets also wrap at 16 bits. MDS
  pointers wrap before lengthening, while the second word of an MDS double
  read follows the lengthened address without another short-pointer wrap.
* Page zero and addresses outside virtual memory raise `DBPointerTrap`.
  Vacant mapped-space pages raise `DBPageFault`; protected writes raise
  `DBWriteProtectFault`. Memory exceptions carry an `address` userInfo value.
* Memory owns its C buffers. The processor retains memory. The borrowed
  state pointer and memory accessor transfer no ownership. There are no
  mutable process-wide processor registers.
* Instances require external serialization. The bounded runner provides a
  scheduling boundary; it is not yet the emulated process scheduler.

## Exceptions and deliberate differences

Dwarf dispatches traps and faults into Mesa/Pilot handlers. This port currently
raises named Foundation exceptions to its caller. `step` restores the complete
register and stack snapshot when an instruction fails. Memory writes already
completed are not reverted. This behavior supports debugging and retrying the
implemented straight-line instructions; it must not be mistaken for Mesa
process-fault dispatch. Restartable block transfers will need per-unit progress
state rather than restarting an entire overlapping transfer.

Double-word push/pop preflight their full stack capacity. Intermediate arithmetic
uses wider or unsigned C types so Java's wraparound behavior does not introduce
C signed-overflow undefined behavior. IEEE floating values use `memcpy` to avoid
aliasing violations. The scalar shifts explicitly handle out-of-range counts.

## Continuing the port

The next engine work is frame allocation, old/new control transfers, architectural
trap dispatch, and state vectors. Then add process scheduling and restartable
block/bit transfers. Boot support depends on those pieces and the selected
machine's memory map and devices. Duchess uses device agents; Draco requires
the much larger 6085 I/O processor and different disk-image handling. A GNUstep
AppKit frontend should consume a machine display/input interface after those
services are implemented.

Header documentation is authoritative for the current public API. The reference
instruction names remain in the generated methods to make comparison with the
Java source straightforward.
