# Verification plan

The software-tool release uses Python unit tests for encoding, round trips, diagnostics, and
the generated ISA binding, plus black-box C++ emulator tests for arithmetic,
predication, uniform and divergent branches, aligned memory, vector-add
semantics, exit, illegal instructions, and SIMT-stack overflow/underflow.
Seeds must be printed for randomized tests. `make test` is the
single regression entry point.

Later modules require self-checking unit tests and assertions before integration.
The closure matrix covers every opcode/register/predicate/lane/warp; RAW and
multi-cycle completion; active-mask categories and nested divergence; shared
conflict degree/broadcast; coalescing degree; scheduler-ready counts; AXI
backpressure; barrier order; and every fault. Crosses are opcode×mask,
opcode×dependency, scheduler×ready count, memory×coalescing, branch×divergence,
and shared operation×conflict. RTL traces will be compared at first mismatch with
the emulator's PC, instruction, masks, writes, memory, stack, and fault events.

The decoder unit test exercises every allocated opcode, signed
immediate extraction, all output metadata classes, a reserved opcode, and a
representative violation of each canonical-field rule. It runs as a compiled
SystemVerilog simulation through `make rtl-test`; XSim separately compiles and
elaborates the same decoder and testbench through `make xsim-smoke`.

The replicated vector-register-file test initializes and reads all 64 logical
warp/register addresses across all eight lane banks. It checks two independent
read addresses, complementary partial masks, inactive-lane preservation,
same-cycle forwarding on both ports, forwarding rejection for a different warp,
invalid-read behavior, and the per-lane replica-write assertions.

The predicate-register-file test covers all 16 warp/predicate addresses, all
eight lane bits, full and complementary partial masks, same-cycle forwarding,
warp and predicate forwarding rejection, invalid reads, reset recovery, masked
write assertions, and unmasked-lane preservation assertions.

The integer-lane/vector-ALU test covers every arithmetic, logic, shift,
comparison, movement, selection, special-register, branch, and memory-address
operation. It explicitly checks two's-complement `MIN`/`MAX`/comparisons,
low-32-bit multiply, five-bit shift amounts, immediate sign extension, inactive
output suppression, predicate inversion and gating, `SEL` on every active lane,
write masks, unsupported operations, and vector address/store-data generation.
