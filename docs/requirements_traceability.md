# Requirements traceability

This matrix connects the normative contracts in `docs/architecture.md` to their
implementation and verification evidence. `Planned` means the contract is frozen
but the named artifact does not yet exist. A requirement cannot close with a
blank evidence category; justified exclusions must be written explicitly.

| Requirement | RTL | Directed test | Assertion/formal | Coverage | Status |
|---|---|---|---|---|---|
| Completion commits exactly once or is explicitly cancelled | Completion fabric | Completion collision/cancellation test | Queue conservation and exactly-once properties | Commit/cancel reason crosses | Planned |
| Round-robin scheduler services a continuously eligible warp within four accepted grants | Warp scheduler | Four-warp fairness stress | Bounded scheduler fairness | Warp × ready-count × wait bins | Planned |
| Round-robin writeback services a continuously nonempty source within three accepted commits | Writeback arbiter | Three-source collision test | Bounded arbiter fairness | Source × collision × wait bins | Planned |
| GPR pending state sets only on accepted issue and clears only on matching commit | GPR scoreboard | RAW/WAW and stalled-commit tests | Scoreboard set/clear matching | Opcode × dependency | Planned |
| Predicate pending state has no forwarding and clears only on matching commit | Predicate scoreboard and register file | Predicate RAW/WAW tests | No early visibility; matching clear | Predicate producer × consumer | Partial: register-file behavior verified |
| Stale epochs have no architectural or memory side effects | `rtl/execute/architectural_writeback.sv`; remaining commit points planned | `tb/unit/tb_alu_completion_writeback.sv` | Writeback stale-side-effect assertions; memory properties pending | Source × stale cancellation pending | Partial: ALU writeback verified |
| Epoch reuse is permitted only after full quiescence | Epoch/quiescence controller | Clear, drain, wrap-directed test | Quiescence completeness | Quiescence blocker × launch | Planned |
| Fatal faults immediately block issue/commit and use a dedicated sticky path | ALU writeback suppression implemented; fault controller planned | ALU fatal-versus-ready-writeback test | Writeback fatal-side-effect assertion; global properties pending | Fault class × outstanding source pending | Partial: ALU writeback priority verified |
| Stores within one warp instruction execute in ascending lane order | Memory controllers | Same-bank and same-address store tests | Monotonic service-lane property | Participation mask × conflict degree | Planned |
| A younger same-warp load observes the completed older store | Warp memory serialization | Load-after-store tests | No younger allocation before store commit | Space × alias pattern | Planned |
| Barrier release waits for all required warps and older memory completion | Barrier controller | Four-warp reduction and missing-warp tests | Barrier release preconditions | Arrival order × pending memory | Planned |
| Two-entry completion queues never overwrite, duplicate, or lose payloads | `rtl/execute/completion_queue.sv` | `tb/unit/tb_completion_queue.sv` | Occupancy, valid-tag, and stability assertions; conservation pending formal | Source × occupancy transition pending | Partial: reusable queue component verified |
| Four memory trackers are system-wide with at most one per warp | Tracker allocator | Fifth-operation and same-warp rejection tests | Allocation uniqueness and capacity | Occupancy × requesting warp | Planned |
| Instruction writes while busy are suppressed and fault deterministically | Host/IMEM controller | Repeated busy-write test | No SRAM write while busy | Bus state × busy write | Planned |
| GPR replicas remain consistent after every accepted masked write | Vector register file | Full and partial-mask write tests | Replica consistency assertions | Warp × register × lane mask | Verified at component level |
| Predicate reads expose committed state only | Predicate register file | No-forwarding test | Committed-state read checks | Address × masked write | Verified at component level |
| Same-cycle events obey reset, clear, fatal, commit, then progress priority | Global control and commit gating | Pairwise event-collision tests | Lower-priority side-effect suppression | Higher event × lower event | Planned |
| Vector memory faults are instruction-atomic | Memory validation front end | One-invalid-lane load/store tests | No request before all-lane validation | Space × lane × fault type | Planned |
| Kernel done requires all warps exited and complete machine drain | Kernel controller | Last-EXIT with every backlogged structure | Done implies quiescent and not faulted | Final event × outstanding structure | Planned |
| EXIT deactivates only its effective lane mask | Warp/SIMT controller | Predicated and divergent EXIT tests | Mask removal and deferred-path preservation | Exit mask × stack state | Planned |
| Sequence matching uses 16-bit sequence plus epoch and warp | Issue tags and all delayed paths | Wrap-near-boundary tag test | No mismatched scoreboard clear/commit | Source × tag fields | Planned |
| Architectural counters wrap at 64 bits and diagnostic counters saturate at 32 bits | Performance counters | Boundary and saturation tests | Width/update/saturation properties | Counter class × boundary | Planned |
| Debug uses a bounded coherent snapshot without a full GPR mux | Debug snapshot unit | Live and fault snapshot tests | Snapshot stability and field coherence | Trigger × captured structure | Planned |
| Ungated baseline and any later clock gating preserve behavior and scan visibility | Clock/test control | Functional and scan gating tests | Enable equivalence and gating checks | Mode × enable state | Planned |

The matrix expands as implementation proceeds. Detailed report paths, test names,
property identifiers, coverage percentages, owners, and waiver links replace the
generic artifact names before verification closure.
