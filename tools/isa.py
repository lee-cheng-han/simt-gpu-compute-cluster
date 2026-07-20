#!/usr/bin/env python3
"""Canonical ISA loader and encoding helpers."""
from __future__ import annotations
import json, pathlib, re, struct

ROOT = pathlib.Path(__file__).resolve().parents[1]
SPEC = json.loads((ROOT / "isa/isa.json").read_text())
OPS = {x["name"]: x for x in SPEC["opcodes"]}
BY_CODE = {x["code"]: x for x in SPEC["opcodes"]}
REG = re.compile(r"R(\d+)$", re.I); PRED = re.compile(r"P(\d+)$", re.I)

class ISAError(ValueError): pass
def register(s):
    m=REG.fullmatch(s.strip()); n=int(m.group(1)) if m else -1
    if not 0 <= n < 16: raise ISAError(f"invalid register '{s}' (expected R0..R15)")
    return n
def predicate(s):
    m=PRED.fullmatch(s.strip()); n=int(m.group(1)) if m else -1
    if not 0 <= n < 4: raise ISAError(f"invalid predicate '{s}' (expected P0..P3)")
    return n
def signed(s, bits=10):
    try: n=int(s,0)
    except ValueError as e: raise ISAError(f"invalid integer '{s}'") from e
    if not -(1<<(bits-1)) <= n < (1<<(bits-1)): raise ISAError(f"immediate {n} does not fit signed {bits} bits")
    return n & ((1<<bits)-1)
def sext(n,bits=10): return n-(1<<bits) if n & (1<<(bits-1)) else n
def word(op, guard=None, invert=False, rd=0, ra=0, rb=0, imm=0):
    return (OPS[op]["code"]<<26)|((guard is not None)<<25)|(invert<<24)|((guard or 0)<<22)|(rd<<18)|(ra<<14)|(rb<<10)|(imm&0x3ff)
def words_from_file(path):
    b=pathlib.Path(path).read_bytes()
    if len(b)%4: raise ISAError("binary length is not a multiple of four bytes")
    return list(struct.unpack("<%dI"%(len(b)//4),b))

