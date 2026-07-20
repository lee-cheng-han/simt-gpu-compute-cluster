# ISA

Instructions are fixed-width, little-endian 32-bit words. `isa/isa.json` is the
canonical machine-readable definition; generated C++ bindings and Python tools
derive from it.

Bits 31:26 are opcode, 25 enables guarding, 24 inverts it, 23:22 select P0--P3,
21:18 are Rd/Pd, 17:14 Ra, 13:10 Rb, and 9:0 are a signed immediate. Register
forms use named fields; `MOVI` uses signed imm10. Loads/stores use `[Ra+imm10]`.
Branches and `SSY` encode a signed PC-relative imm10 in instruction words, from
the following PC, giving a -512..+511 instruction range. Labels are preferred.
Unused fields must be zero; non-canonical encodings and opcodes 31--63 fault as
`ILLEGAL_INSTRUCTION` before side effects. Reserved special-register values fault.

Syntax includes `ADD R1, R2, R3`, `MOVI R1, -4`, `LD.G R2, [R1+4]`,
`ST.G [R1], R2`, `SETP.LT P0, R1, R2`, `@P0 BRA label`, `@!P1 ADD ...`,
`SSY join`, `SYNC`, `BAR`, and `EXIT`. `SEL Rd, Ra, Rb` chooses Ra when its
encoded predicate (after optional inversion) is true and Rb otherwise. `SEL`
requires `@P<n>` or `@!P<n>`, but that field selects data rather than masking
the destination write; all currently active lanes write one of the two sources.
All accesses are aligned 32-bit in the baseline. `BAR` must be unpredicated and
executed with a full active mask. Misuse produces a defined fault.

Opcodes 0--31 are allocated in `isa/isa.json`; encodings 32--63 are reserved.
`SSY` pushes a token, a guarded `BRA` fills its deferred-path fields when the
mask splits, and `SYNC` services or pops the token. `SSY` on a full depth-8 stack
faults without modifying it. `SYNC` on an empty stack faults without advancing
the PC or changing the active mask. Any warp stack fault is a fatal kernel fault.
