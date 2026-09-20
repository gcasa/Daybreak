# Validation

Validated on 2026-09-20 against Dwarf commit
`c264af5e37f89d7aa0eec968aa23818bf5a89837`.

* 358 regression checks pass: page maps, flags, protection and pointer faults;
  byte and double-word ordering; all valid field positions and widths; stack
  limits and recovery; arithmetic edge cases; signed/unsigned jumps and PC
  wrapping; both global-frame modes; opcode traps; and memory-fault retry.
* 5,837 successful arithmetic and jump executions match the unmodified Java
  reference, comparing PC, stack depth, and all fourteen stack slots.
* AddressSanitizer and UndefinedBehaviorSanitizer pass using Homebrew LLVM
  and Apple Foundation, with ARC disabled.
* GCC 16 with the GNU Objective-C runtime and GNUstep Base 1.31.1 compiles
  the port and passes the regression suite and Java comparisons. The native
  GNUstep make 2.9.3 build also passes the command-line demo.
* Autogsdoc generates HTML and GSDoc XML from all four headers without
  parser warnings. All 308 methods have descriptions; the XML validates
  against the GSDoc 1.0.4 DTD.
* The Objective-C 1.0 syntax guard passes.

GNUstep verification used an isolated temporary build on macOS ARM64.
The GNUstep build needed host-toolchain compatibility adjustments; this
is not a claim of testing every stock GNUstep distribution. An Ubuntu/GCC
CI workflow is included but has not been run in this workspace.

The memory and assignment tests are targeted regressions. The differential
harness currently covers successful stack/arithmetic/jump instructions, not
all assignments or the reference's guest trap dispatch. No Xerox operating
system boot or peripheral tests are claimed.
