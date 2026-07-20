# Coding conventions

RTL uses explicit-width `logic`, `always_ff`, `always_comb`, synchronous active
high `rst`, valid/ready interfaces, packed structs/enums where useful, no inferred
latches or simulation delays, and deterministic illegal-condition handling.
Architectural modules do not instantiate vendor primitives. C++ builds as C++17
with warnings as errors; the baseline Python tools use only the standard library.
