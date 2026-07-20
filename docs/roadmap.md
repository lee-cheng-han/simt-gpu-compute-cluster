# Development roadmap

The project uses an ASIC-first, FPGA-proven development order. The architectural
SIMT cluster remains technology independent. ASIC and FPGA memory, clocking, and
host interfaces are implemented only behind wrappers or top-level boundaries.

The ASIC deliverable is a reproducible synthesis and physical-design study using
an open PDK, not a fabrication claim. The final FPGA deliverable is real execution
on the Zybo Z7-20.

## Milestones 0 and 1: architecture and software tools

Status: complete. The architectural contracts, canonical ISA, assembler,
disassembler, functional emulator, programs, and software regression exist.

## Milestone 2: single-warp vector processor

Status: in progress; the decoder plus vector and predicate register files are
complete. Build one eight-thread warp with
fetch, lane-banked replicated vector registers, predicate registers, eight
integer lanes, writeback, and a non-AXI memory model. Acceptance requires vector
addition, forwarding and replica checks, masked-write preservation, and emulator
agreement.

## Milestone 3: four warps, scheduler, and scoreboard

Add four warp contexts, round-robin scheduling, per-warp dependency tracking, a
multi-cycle multiplier, blocking, and wakeup. Acceptance requires fair progress
and correct RAW/WAW behavior under backpressure.

## Milestone 4: shared memory

Add eight banks, conflicts, replay, read broadcast, and counters. No active lane
request may be lost or duplicated, and all conflict categories must match the
emulator.

## Milestone 5: divergence and reconvergence

Add active-mask control and the depth-8 SIMT stack using `SSY`/`BRA`/`SYNC`.
Acceptance includes uniform, partial, alternating, nested, overflow, and
underflow cases with side-effect suppression on faults.

## Milestone 6: global-memory coalescing

Add 32-byte segment grouping, four-beat 64-bit transactions, byte enables,
request metadata, lane response mapping, and a randomized protocol-level memory
model. The cluster-facing interface remains independent of AXI details.

## Milestone 7: thread blocks and barriers

Add one resident block of up to four warps, dispatch, barrier arrival/release,
block completion, programming-model error checks, and a simulation watchdog.
Acceptance includes a shared-memory parallel reduction.

## Milestone 8: standalone verification closure

Close assertions, explicit functional coverage, constrained random programs,
emulator/RTL differential traces, fault injection, and long regressions. Every
feature must map to tests and coverage, with no unexplained failures remaining.

This is the physical-implementation entry gate. The standalone cluster must be
synthesizable and contain no FPGA-specific primitives.

## Milestone 9: ASIC synthesis and physical design

Create ASIC-compatible memory wrappers and run a reproducible Yosys/OpenROAD flow
with a supported open PDK. Perform lint, synthesis, mapping, floorplanning,
placement, clock-tree synthesis, routing, static timing, area, power, congestion,
and critical-path analysis.

Evaluate area-oriented, balanced, and performance-oriented configurations. All
results must be identified as estimates from a non-fabricated study.

## Milestone 10: ASIC-driven optimization and re-verification

Use physical evidence to motivate at least two RTL or microarchitecture changes.
Record before/after PPA, congestion, timing, and benchmark effects. Run the full
architectural regression after every change and retain the best verified core.

## Milestone 11: Zynq host and FPGA integration

Add FPGA BRAM wrappers, AXI4-Lite control, the AXI4 DDR master, command processor,
Zynq processing-system integration, bare-metal ARM runtime, kernel loader, and
completion/error handling. FPGA wrappers preserve the ASIC core's memory contract.

## Milestone 12: FPGA bring-up and optimization

Run kernels on the Zybo Z7-20, compare against the ARM reference, close timing at
50 MHz, and pursue 75--100 MHz. Report LUT, flip-flop, BRAM, DSP, timing,
benchmark cycles, lane utilization, warp IPC, and memory efficiency.

## Backend relationship

```text
Verified technology-independent SIMT cluster
├── ASIC backend: SRAM wrappers and open-PDK physical-design study
└── FPGA backend: BRAM wrappers, AXI, Zynq ARM, DDR, and board execution
```

Floating point, packed INT8, caches, virtual memory, multiple clusters, graphics,
and commercial programming-API compatibility remain post-baseline work.
