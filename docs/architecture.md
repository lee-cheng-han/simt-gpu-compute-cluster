# Architecture

The baseline is one compute cluster with 8 physical lanes, 8 threads per warp,
4 resident warps (32 threads), and one resident block. Each thread has sixteen
32-bit general registers and four predicate registers. Warps issue in order and
share a PC, 8-bit active mask, scoreboard, barrier state, and depth-8 SIMT stack.

The target is XC7Z020 at 50 MHz initially (75--100 MHz stretch). Instruction
memory is 4--8 KiB, shared memory is 8 KiB in eight word-interleaved banks, and
global memory uses 32-byte segments over a 64-bit AXI master. Architectural RTL
uses technology-independent memory wrappers. The vector register file baseline
is eight lane banks, each replicated for two reads and updated identically by one
masked write port with explicit same-cycle forwarding.

Register storage is not bulk-reset: clearing 512 words in reset logic would
prevent efficient SRAM/BRAM inference and is not required for correctness.
Dispatch or software must initialize every register that a kernel reads. Reset
suppresses writes and invalid reads return deterministic zero. Forwarding matches
write validity, warp, register, and lane mask; unselected lanes use stored data.
Simulation assertions prove that an accepted lane write becomes identical in
both physical replicas on the following cycle.

The implementation sequence is contract/tools, single warp, multi-warp
scheduling, shared memory, divergence, global memory, barriers, standalone
verification closure, ASIC physical implementation, ASIC-driven RTL refinement,
and finally Zynq integration and FPGA bring-up. The complete ordering and entry
gates are defined in `docs/roadmap.md`. Floating point, caches, multiple clusters,
coherence, and virtual memory are explicitly outside the baseline.

## Milestone 2 decoder contract

The combinational decoder exposes raw register, predicate, and signed-immediate
fields plus dependency metadata (`uses_ra`, `uses_rb`, general/predicate write),
memory classification, and branch classification. `legal` is asserted only for
allocated opcodes with all format-reserved fields zero. The opcode package is
generated from `isa/isa.json`; the RTL does not maintain a second opcode table.
For ordinary predicated instructions `guard_exec` marks lane-mask gating. For
`SEL`, the predicate is a data selector and `guard_exec` is clear.
