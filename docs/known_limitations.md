# Known limitations

The current emulator executes one warp and models architectural behavior rather
than pipeline timing. Multi-warp scheduling, completion-queue integration, epochs, memory
trackers, bank replay, barriers, Wishbone, DFT, SRAM macros, formal closure, and
physical implementation are not yet integrated. The canonical completion record
and reusable two-entry queue are component-verified. Tagged ALU completion,
epoch-aware architectural writeback, and the four-warp tagged dependency
scoreboards are verified as components. The first single-warp top level executes
integer, comparison, movement, predication, `S2R`, and lane-level `EXIT` programs.
`MUL`, memory, branches, barriers, reconvergence, the dedicated fault controller,
four-warp scheduling, and three-source arbitration remain absent from that top.
The older one-entry writeback buffer is retained only as preliminary component
history and is not the architectural path.
Assembly memory images are simple text fixtures rather than an ELF ABI.
