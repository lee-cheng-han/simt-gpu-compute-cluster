# Known limitations

The current emulator executes one warp and models architectural behavior rather
than pipeline timing. Multi-warp scheduling, completion-queue integration, epochs, memory
trackers, bank replay, barriers, Wishbone, DFT, SRAM macros, formal closure, and
physical implementation are not yet integrated. The canonical completion record
and reusable two-entry queue are component-verified. Tagged ALU completion and
epoch-aware architectural writeback are verified together, but the multiplier/
memory sources, three-source arbiter, and integrated scoreboards remain absent.
The older one-entry writeback buffer is retained only as preliminary component
history and is not the architectural path.
Assembly memory images are simple text fixtures rather than an ELF ABI.
