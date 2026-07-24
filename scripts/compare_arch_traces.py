#!/usr/bin/env python3
import pathlib, sys
def main():
    if len(sys.argv)!=3: raise SystemExit("usage: compare_arch_traces.py EXPECTED ACTUAL")
    a=pathlib.Path(sys.argv[1]).read_text().splitlines(); b=pathlib.Path(sys.argv[2]).read_text().splitlines()
    for i,(x,y) in enumerate(zip(a,b),1):
        if x!=y: raise SystemExit(f"first architectural mismatch at trace line {i}\nexpected: {x}\nactual:   {y}")
    if len(a)!=len(b): raise SystemExit(f"trace length mismatch expected={len(a)} actual={len(b)}")
    print(f"PASS architectural trace comparison events={len(a)//3}")
if __name__=="__main__": main()
