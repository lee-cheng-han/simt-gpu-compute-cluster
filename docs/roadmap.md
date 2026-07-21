# Tapeout development roadmap

This roadmap is subordinate to `docs/architecture.md`. Release stages are named
by their engineering exit criteria rather than internal sequence numbers.

## Specification merge

Audit existing code and tests, freeze one authoritative contract, remove
contradictory legacy platform descriptions, and preserve passing work.
Create and maintain `docs/requirements_traceability.md`, mapping every normative
requirement to RTL, directed tests, assertions/formal properties, coverage, and
current status.
Exit requires clean Python, C++, Verilator, and XSim regressions and no unresolved
policy conflict. The traceability matrix must contain no unowned requirement.

## SRAM and implementation feasibility

Before architectural freeze, select actual instruction, scratchpad, and shared
SRAM macros from the chosen open-PDK flow. Confirm supported widths and depths,
logical banking, Liberty/LEF/GDS/model availability, power-pin compatibility,
BIST-port feasibility, preliminary placement, routing channels, and timing across
each macro boundary. Run early synthesis and a trial floorplan around those real
views. Behavioral wrappers may remain during core development, but memory size,
banking, timing, and floorplan assumptions cannot freeze without this evidence.

## Integrated single-warp processor

Connect instruction memory, fetch, decode, dependency checks, register files,
predicate state, eight ALU lanes, ALU completion queue, architectural writeback,
and exit. Execute movement, arithmetic, logic, shifts, comparisons, predication,
`SEL`, `S2R`, and `EXIT` with instruction-level emulator agreement.
The GPR and predicate scoreboard skeleton is part of this integration, so this
stage is not limited to manually scheduled dependency-safe programs.

## Four-warp execution and multiplier

Extend the scoreboards across all warp state, add round-robin scheduling, three-stage
multiplier, multiplier queue, two-source arbitration, epoch/quiescence, and
scheduler/arbiter fairness. Publish one-warp versus four-warp arithmetic results.

## Divergence and reconvergence

Integrate branch masks, `SSY`, `SYNC`, nested SIMT stack behavior, redirects, and
fatal stack faults with differential and formal evidence.

## Shared memory and barriers

Integrate eight shared banks, replay, broadcast, tracker behavior, barriers,
ordering, and deadlock watchdog. Exit requires a passing multi-warp reduction.

## General scratchpad and memory completion

Integrate the 4 KiB eight-bank scratchpad, four trackers, response collector,
memory queue, three-source arbitration, store ordering, load visibility, and
stale-response rejection. A fifth operation and second same-warp operation must
backpressure safely.

## Standalone-core release

Complete workloads, counters, fault model, differential traces, random generation,
emulator memory ordering, and quantitative scheduler/memory/divergence studies.
Shared-memory reduction is the flagship end-to-end workload. It must exercise
four-warp scheduling, bank conflicts and replay, barriers, predication, ordering,
and performance counters. Matrix multiplication is a secondary workload.

## Verification closure

Close assertions, bounded formal properties, numerical functional coverage,
long seeded regressions, fairness stress, bug injection, requirements traceability,
and documented limitations. No unexplained mismatch may remain.

## Continuous-integration release gate

Every merge candidate runs canonical ISA-generation consistency, assembler and
disassembler tests, emulator tests, RTL lint, Verilator unit tests, selected
integration programs, architectural trace comparison, documentation-link and
contract-consistency checks, and `git diff --check`. The required set must pass
from a clean checkout with pinned tool versions. XSim, long random regressions,
formal proofs, synthesis, DFT, and physical implementation remain scheduled or
manually triggered jobs whose reports are required at their release gates.

## ASIC architecture freeze

Use early synthesis and floorplanning to freeze ISA, pipeline, register-file
organization, SRAM macros, queue depths, epoch, host map, clock/reset, DFT ports,
physical hierarchy, and the selected MPW harness contract. Exit requires qualified
SRAM views, preliminary macro placement and boundary timing, and no unresolved
architectural dependency on an assumed memory implementation.

## Static RTL signoff

Close RTL lint, clock-domain crossings, reset-domain crossings, reset assertion
and deassertion behavior, and functional/host/scan/BIST clock interactions before
the synthesis freeze. Review every crossing and document every synchronizer,
false path, asynchronous path, and tool waiver. Exit requires clean reports or
explicitly justified exceptions with owners.

## Host and SRAM integration

Add the internal bus, Wishbone wrapper, SRAM macro wrappers and views, host
loading/launch, quiescence/fault reporting, ownership checks, and instruction-write
busy fault.

## MPW harness integration

Deliver a harnessed digital macro: integrate the selected shuttle harness, address
and I/O map, top-level power connections, clocks and resets, Wishbone attachment,
and submission configuration. Close harness timing, full-wrapper DRC/LVS, shuttle
prechecks, and submission-specific repository validation. A standalone pad ring,
package, and board are outside this release target.

## DFT release

Complete scan architecture and simulation, supported ATPG reporting, destructive
SRAM BIST, test ownership, and functional/scan/BIST timing constraints.

## Physical implementation

Complete synthesis, floorplan, macro placement, PDN, placement, CTS, routing,
extraction, timing optimization, antenna repair, fill, re-extraction, and ECO loop.
Every violation enters a tracked loop: root-cause analysis, RTL or physical ECO,
incremental implementation, extraction, STA, equivalence, DRC/LVS, and affected
functional regressions. An ECO closes only when all impacted evidence is rerun.

## Signoff and GDS release

Complete supported MMMC STA, activity-based power, IR/EM review, DRC, LVS,
antenna, density/connectivity, equivalence, GLS/SDF, scan/BIST validation, release
audit, archived reports/checksums, bring-up firmware, and silicon test plan. The
filled GDS is the signoff database. After final fill, rerun extraction, setup/hold
STA, DRC, LVS, antenna, density, power review, and final-netlist consistency; no
pre-fill result may substitute for this exit gate.
