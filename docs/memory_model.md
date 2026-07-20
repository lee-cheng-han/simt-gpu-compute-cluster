# Memory model

Global and shared spaces are distinct, byte-addressed, little-endian arrays.
Baseline lane accesses are aligned 32-bit words; misalignment or out-of-range
access faults before any lane commits, making a warp instruction atomic in the
functional model. No caches, coherence, virtual memory, or ordering scopes exist.

The RTL global coalescer will group active lanes by 32-byte aligned segment and
transfer each segment as four 64-bit AXI beats. Shared memory is 8192 bytes in
eight banks, with bank `(byte_address >> 2) mod 8`; conflicts replay, while equal
read addresses broadcast. Instructions before a barrier complete before arrival,
and release is the visibility point for participating warps.

