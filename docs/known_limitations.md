# Known limitations

The current emulator executes one warp and models architectural behavior rather
than pipeline timing. Multi-warp scheduling, completion-queue integration, epochs, memory
trackers, bank replay, barriers, Wishbone, DFT, SRAM macros, formal closure, and
physical implementation are not yet integrated. The canonical completion record
and reusable two-entry queue are component-verified, but the existing writeback
buffer remains preliminary and does not implement the three-source fabric.
Assembly memory images are simple text fixtures rather than an ELF ABI.
