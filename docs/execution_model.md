# Execution model

An instruction is applied to the lanes in `active_mask` whose optional predicate
guard is true. Inactive lanes have no register, predicate, memory, barrier, or
control-flow side effect. Arithmetic is modulo 2^32; signed comparisons, `MIN`,
`MAX`, and `SAR` interpret operands as two's-complement.

The Milestone-1 emulator runs one warp of eight lanes deterministically. Each
lane starts with zeroed registers and predicates; P0--P3 are ordinary predicate
registers. R0 is writable. Memory is little-endian and byte addressed.

`SSY reconv` pushes a reconvergence token and establishes the reconvergence PC
for the next potentially divergent `BRA`. The instruction at `reconv` must be
`SYNC`. This explicit three-instruction protocol (`SSY`, guarded `BRA`, `SYNC`)
keeps the branch encoding unambiguous and makes stack errors architecturally
observable.
For a guarded branch, taken and fall-through masks are computed from the current
active mask. Uniform outcomes simply select the next PC. A partial outcome pushes
`{reconv_pc, fallthrough_pc, fallthrough_mask}` and executes the taken path first.
At `SYNC`, deferred paths execute before a second arrival restores the union
mask and pops the entry. A uniform region pops at its first `SYNC`. Nested
regions use a depth-8 stack. `SSY` while full or `SYNC` while empty is a fatal sticky
kernel fault: stack and architectural side effects are preserved/suppressed,
respectively, and another launch requires clear/reset. Full RTL realization is
Milestone 5, but the model contract is frozen here.

In-order issue plus refusing a destination already pending prevents WAW hazards;
source pending bits prevent RAW hazards. The model is functional and completes
each instruction atomically, while later RTL may interleave stalled warps.
