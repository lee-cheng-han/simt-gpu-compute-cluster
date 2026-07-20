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

The predicate file stores one eight-bit lane mask for each of four predicate
registers in each warp. Its 128 state bits use resettable flip-flops rather than
a bulk memory because deterministic false predicates after reset are useful and
the storage cost is small. Writes carry an independent lane mask, and same-cycle
forwarding uses validity, warp, predicate index, and lane selection.

The integer execution unit is composed of one combinational `integer_lane` per
physical lane and an eight-lane wrapper. The wrapper computes the execution mask
from instruction validity, the active mask, and the selected predicate. `SEL`
uses its predicate only for data selection and therefore does not gate execution.
The baseline multiplier is combinational for single-warp integration; the
multi-cycle pipelined multiplier and warp wakeup protocol are added with the
multi-warp scheduler and scoreboard.
Memory operations produce aligned-address candidates and store data but do not
perform memory side effects inside the ALU.

The architectural PC is a 32-bit instruction-word index. The baseline
instruction-memory wrapper provides a combinational read and a synchronous
programming port, allowing one fetch per cycle when downstream is ready. The
fetch unit buffers its output, holds PC and instruction stable under backpressure,
discards buffered sequential work on redirect, and reports a sticky range fault.
Programming and fetching the same word concurrently is an illegal integration
condition checked by assertion. A registered SRAM/BRAM backend may be introduced
behind an adapter while preserving the fetch valid/ready contract.

The implementation sequence is contract/tools, single warp, multi-warp
scheduling, shared memory, divergence, global memory, barriers, standalone
verification closure, ASIC physical implementation, ASIC-driven RTL refinement,
and finally Zynq integration and FPGA bring-up. The complete ordering and entry
gates are defined in `docs/roadmap.md`. Floating point, caches, multiple clusters,
coherence, and virtual memory are explicitly outside the baseline.

## Decoder contract

The combinational decoder exposes raw register, predicate, and signed-immediate
fields plus dependency metadata (`uses_ra`, `uses_rb`, general/predicate write),
memory classification, and branch classification. `legal` is asserted only for
allocated opcodes with all format-reserved fields zero. The opcode package is
generated from `isa/isa.json`; the RTL does not maintain a second opcode table.
For ordinary predicated instructions `guard_exec` marks lane-mask gating. For
`SEL`, the predicate is a data selector and `guard_exec` is clear.
