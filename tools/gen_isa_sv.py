#!/usr/bin/env python3
"""Generate the SystemVerilog ISA package from the canonical JSON specification."""
from __future__ import annotations

import argparse
import json
import pathlib


def generate(spec_path: pathlib.Path) -> str:
    spec = json.loads(spec_path.read_text())
    opcodes = ",\n".join(
        f"    OP_{entry['name'].replace('.', '_')} = 6'd{entry['code']}"
        for entry in spec["opcodes"]
    )
    special = ",\n".join(
        f"    SR_{name} = 10'd{code}"
        for name, code in spec["special_registers"].items()
    )
    return f"""// Generated from isa/isa.json by tools/gen_isa_sv.py; do not edit.
package simt_isa_pkg;
  typedef enum logic [5:0] {{
{opcodes}
  }} opcode_t;

  typedef enum logic [9:0] {{
{special}
  }} special_reg_t;
endpackage
"""


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("spec", type=pathlib.Path)
    parser.add_argument("output", type=pathlib.Path)
    args = parser.parse_args()
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(generate(args.spec))


if __name__ == "__main__":
    main()
