# Known limitations

The current functional model executes one warp. `SSY`/divergence fault semantics
are represented, but cycle timing, multi-warp barriers, replay, coalescing, AXI,
and synthesizable execution RTL are being integrated incrementally. Assembly memory
images are intentionally simple text fixtures rather than an ELF ABI.
