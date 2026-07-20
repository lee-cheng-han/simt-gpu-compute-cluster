# FPGA-Based Programmable SIMT GPU Compute Cluster

An FPGA-oriented custom SIMT compute architecture targeting the Zybo Z7-20. It is
not CUDA or OpenCL compatible. Milestones 0 and 1 freeze the architectural and
ISA contracts and provide executable software tools; synthesizable execution RTL
begins in Milestone 2.

## Current status

```text
Release:       v0.2 in progress
Completed:     ISA tools, emulator, decoder, replicated vector register file
Passing:       Software regression plus decoder and register-file RTL tests
Next:          Predicate register file
Not started:   Multi-warp core, verification closure, ASIC and FPGA backends
```

## Quick start

```sh
make test
make assemble PROGRAM=tb/programs/vector_add.s
build/simt-emulator build/vector_add.bin --memory tb/programs/vector_add.mem
```

Requirements are Python 3.8+, a C++17 compiler, GNU Make, and (only for the
RTL unit tests) Verilator 5+. Vivado/XSim 2025.2 is used only by the optional
`make xsim-smoke` compile/elaboration check. See `docs/` for the frozen contracts.

## Implementation strategy

The compute cluster is developed as technology-independent, ASIC-quality RTL.
After standalone verification closure, it receives an open-PDK ASIC synthesis
and physical-design study. Physical results drive a re-verified optimization
pass before Zynq integration and real execution on the Zybo Z7-20. See
[`docs/roadmap.md`](docs/roadmap.md) for the milestone gates and deliverables.
