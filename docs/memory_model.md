# On-chip memory model

This document expands the normative policies in `architecture.md`.

Instruction SRAM, the 4 KiB general-data scratchpad, and 2 KiB shared memory are
distinct, byte-addressed, little-endian spaces. Core data accesses are 32-bit
words with `byte_enable = 4'b1111`. An active-lane address must be four-byte
aligned and its complete word must be in range: `0x000`--`0xffc` for scratchpad
and `0x000`--`0x7fc` for shared memory. Misaligned accesses are not split.
Inactive-lane addresses are neither checked nor serviced. Wishbone host writes
honor per-byte selects; byte address zero maps to data bits 7:0.

Vector memory faults are instruction-atomic. Controllers first collect and
validate every active-lane address before issuing any bank request. If any active
lane is misaligned or out of range, the instruction raises a fatal fault: a load
commits no register result and a store performs no lane write. Validation failure
therefore cannot leave a partially updated memory instruction. Once validation
succeeds, stores follow the service ordering below and are cancelled only by a
higher-priority reset, host clear, or fatal event as defined by the architecture.

Both data memories use eight word-interleaved banks:

```text
word_address = byte_address >> 2
bank_index   = word_address[2:0]
bank_row     = word_address >> 3
```

The scratchpad has 128 rows/bank; shared memory has 64. One distinct request per
bank is serviced each cycle. Identical-address loads broadcast. Other conflicts
replay without loss or duplication.

Stores within one warp instruction are serviced in ascending lane order. For a
same-address collision, the highest participating lane writes last and determines
the final value. A younger same-warp load cannot issue until the older memory
instruction completes and commits, so it sees that final value. Cross-warp races
are unordered unless a completed barrier provides synchronization.

Four trackers permit one outstanding memory instruction per resident warp. The
tracker table preserves epoch, sequence, metadata, lane mappings, pending and
completed masks, results, and fault state. The response collector emits at most
one completed tracker per cycle into the two-entry memory completion queue.

SRAM contents are undefined after reset and destructive BIST. Reset and host
clear do not write SRAM; host clear preserves physical contents. Required memories
must be explicitly loaded before launch and reloaded after BIST. Instruction SRAM
writes while running are suppressed and raise `IMEM_WRITE_WHILE_BUSY`.
