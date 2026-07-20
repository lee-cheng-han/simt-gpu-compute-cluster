#!/usr/bin/env python3
from __future__ import annotations
import argparse, pathlib, re, struct, sys
sys.path.insert(0,str(pathlib.Path(__file__).resolve().parents[1]))
from isa import OPS, ISAError, predicate, register, signed, word

def split_args(s): return [x.strip() for x in re.split(r",(?![^\[]*\])",s) if x.strip()]
def memory(s):
    m=re.fullmatch(r"\[\s*(R\d+)\s*(?:([+-])\s*([^\]]+))?\s*\]",s,re.I)
    if not m: raise ISAError(f"invalid memory operand '{s}'")
    off=0 if m.group(3) is None else int(m.group(3),0)*(1 if m.group(2)=='+' else -1)
    return register(m.group(1)), signed(str(off))
def assemble(text, source="<string>"):
    rows=[]; labels={}; pc=0
    for line_no,raw in enumerate(text.splitlines(),1):
        line=raw.split('#',1)[0].split(';',1)[0].strip()
        if not line: continue
        while ':' in line:
            label, line=line.split(':',1); label=label.strip()
            if not re.fullmatch(r"[A-Za-z_]\w*",label): raise ISAError(f"{source}:{line_no}: invalid label '{label}'")
            if label in labels: raise ISAError(f"{source}:{line_no}: duplicate label '{label}'")
            labels[label]=pc; line=line.strip()
            if not line: break
        if line: rows.append((line_no,line)); pc+=1
    out=[]
    for pc,(ln,line) in enumerate(rows):
      try:
        guard=None; inv=False
        if line.startswith('@'):
            g,line=line.split(None,1); inv=g.startswith('@!'); guard=predicate(g[2:] if inv else g[1:])
        parts=line.split(None,1); op=parts[0].upper(); args=split_args(parts[1] if len(parts)>1 else '')
        if op=='.WORD':
            if len(args)!=1: raise ISAError('.word expects one operand')
            out.append(int(args[0],0)&0xffffffff); continue
        if op not in OPS: raise ISAError(f"unknown opcode '{op}'")
        fmt=OPS[op]['format']; kw=dict(guard=guard,invert=inv)
        if fmt=='none':
            if args: raise ISAError(f"{op} takes no operands")
        elif fmt=='rrr':
            if len(args)!=3: raise ISAError(f"{op} expects Rd, Ra, Rb")
            kw.update(rd=register(args[0]),ra=register(args[1]),rb=register(args[2]))
        elif fmt=='rr':
            if len(args)!=2: raise ISAError(f"{op} expects Rd, Ra")
            kw.update(rd=register(args[0]),ra=register(args[1]))
        elif fmt=='ri':
            if len(args)!=2: raise ISAError(f"{op} expects Rd, immediate")
            kw.update(rd=register(args[0]),imm=signed(args[1]))
        elif fmt=='prr':
            if len(args)!=3: raise ISAError(f"{op} expects Pd, Ra, Rb")
            kw.update(rd=predicate(args[0]),ra=register(args[1]),rb=register(args[2]))
        elif fmt=='load':
            if len(args)!=2: raise ISAError(f"{op} expects Rd, [Ra+offset]")
            ra,imm=memory(args[1]); kw.update(rd=register(args[0]),ra=ra,imm=imm)
        elif fmt=='store':
            if len(args)!=2: raise ISAError(f"{op} expects [Ra+offset], Rb")
            ra,imm=memory(args[0]); kw.update(ra=ra,rb=register(args[1]),imm=imm)
        elif fmt=='branch':
            if len(args)!=1: raise ISAError(f"{op} expects a label or offset")
            off=labels[args[0]]-(pc+1) if args[0] in labels else int(args[0],0); kw['imm']=signed(str(off))
        elif fmt=='special':
            if len(args)!=2 or args[1].upper() not in __import__('isa').SPEC['special_registers']: raise ISAError(f"{op} expects Rd, special-register")
            kw.update(rd=register(args[0]),imm=__import__('isa').SPEC['special_registers'][args[1].upper()])
        if op=='SEL' and guard is None: raise ISAError('SEL requires @P<n> or @!P<n>')
        out.append(word(op,**kw))
      except (ISAError,ValueError) as e: raise ISAError(f"{source}:{ln}: {e}") from e
    return out
def main():
    p=argparse.ArgumentParser(); p.add_argument('input'); p.add_argument('-o','--output',required=True); a=p.parse_args()
    try: words=assemble(pathlib.Path(a.input).read_text(),a.input)
    except (OSError,ISAError) as e: p.error(str(e))
    pathlib.Path(a.output).write_bytes(struct.pack('<%dI'%len(words),*words))
if __name__=='__main__': main()

