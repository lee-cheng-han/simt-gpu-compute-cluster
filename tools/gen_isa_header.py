#!/usr/bin/env python3
import json, pathlib, sys
s=json.loads(pathlib.Path(sys.argv[1]).read_text())
ops=',\n'.join(f'  {x["name"].replace(".","_")} = {x["code"]}' for x in s['opcodes'])
text=f'''// Generated from isa/isa.json; do not edit.\n#pragma once\n#include <cstdint>\nnamespace simt {{ enum class Opcode : uint8_t {{\n{ops}\n}}; constexpr unsigned kStackDepth=8, kLanes=8, kRegs=16, kPreds=4; }}\n'''
pathlib.Path(sys.argv[2]).write_text(text)

