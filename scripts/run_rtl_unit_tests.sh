#!/usr/bin/env sh
set -eu
command -v verilator >/dev/null 2>&1 || {
  echo 'verilator not found; install Verilator 5 or newer' >&2
  exit 2
}
mkdir -p build/verilator/decoder
python3 tools/gen_isa_sv.py isa/isa.json build/simt_isa_pkg.sv
verilator --binary --timing --assert --Wall \
  --Mdir build/verilator/decoder \
  --top-module tb_instruction_decoder \
  build/simt_isa_pkg.sv \
  rtl/frontend/instruction_decoder.sv \
  tb/unit/tb_instruction_decoder.sv
build/verilator/decoder/Vtb_instruction_decoder

mkdir -p build/verilator/vector_register_file
verilator --binary --timing --assert --Wall \
  --Mdir build/verilator/vector_register_file \
  --top-module tb_vector_register_file \
  rtl/register_file/vector_register_file.sv \
  tb/unit/tb_vector_register_file.sv
build/verilator/vector_register_file/Vtb_vector_register_file

mkdir -p build/verilator/predicate_register_file
verilator --binary --timing --assert --Wall \
  --Mdir build/verilator/predicate_register_file \
  --top-module tb_predicate_register_file \
  rtl/register_file/predicate_register_file.sv \
  tb/unit/tb_predicate_register_file.sv
build/verilator/predicate_register_file/Vtb_predicate_register_file

mkdir -p build/verilator/vector_integer_alu
verilator --binary --timing --assert --Wall \
  --Mdir build/verilator/vector_integer_alu \
  --top-module tb_vector_integer_alu \
  build/simt_isa_pkg.sv \
  rtl/execute/integer_lane.sv \
  rtl/execute/vector_integer_alu.sv \
  tb/unit/tb_vector_integer_alu.sv
build/verilator/vector_integer_alu/Vtb_vector_integer_alu

mkdir -p build/verilator/instruction_fetch
verilator --binary --timing --assert --Wall \
  --Mdir build/verilator/instruction_fetch \
  --top-module tb_instruction_fetch \
  rtl/frontend/instruction_memory.sv \
  rtl/frontend/instruction_fetch.sv \
  tb/unit/tb_instruction_fetch.sv
build/verilator/instruction_fetch/Vtb_instruction_fetch
