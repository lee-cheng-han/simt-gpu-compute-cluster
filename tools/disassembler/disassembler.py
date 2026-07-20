#!/usr/bin/env python3
from __future__ import annotations
import argparse, pathlib, sys
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]))
from isa import BY_CODE, SPEC, sext, words_from_file
def disassemble_word(w):
    code=w>>26
    if code not in BY_CODE: return f".word 0x{w:08x}"
    x=BY_CODE[code]; op=x['name']; fmt=x['format']; pe=(w>>25)&1; inv=(w>>24)&1; p=(w>>22)&3; rd=(w>>18)&15; ra=(w>>14)&15; rb=(w>>10)&15; imm=sext(w&1023)
    guard=(f"@{'!' if inv else ''}P{p} " if pe else '')
    if fmt=='none': body=op
    elif fmt=='rrr': body=f"{op} R{rd}, R{ra}, R{rb}"
    elif fmt=='rr': body=f"{op} R{rd}, R{ra}"
    elif fmt=='ri': body=f"{op} R{rd}, {imm}"
    elif fmt=='prr': body=f"{op} P{rd&3}, R{ra}, R{rb}"
    elif fmt=='load': body=f"{op} R{rd}, [R{ra}{imm:+d}]"
    elif fmt=='store': body=f"{op} [R{ra}{imm:+d}], R{rb}"
    elif fmt=='branch': body=f"{op} {imm:+d}"
    else:
        rev={v:k for k,v in SPEC['special_registers'].items()}; body=f"{op} R{rd}, {rev.get(w&1023,'RESERVED'+str(w&1023))}"
    return guard+body
def main():
    p=argparse.ArgumentParser(); p.add_argument('input'); a=p.parse_args()
    for i,w in enumerate(words_from_file(a.input)): print(f"{i:04x}: {w:08x}  {disassemble_word(w)}")
if __name__=='__main__': main()

