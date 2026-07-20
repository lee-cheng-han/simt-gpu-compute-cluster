#!/usr/bin/env sh
set -eu
command -v xvlog >/dev/null 2>&1 || { echo 'xvlog not found; install/source Vivado 2025.2' >&2; exit 2; }
mkdir -p build/xsim
python3 tools/gen_isa_sv.py isa/isa.json build/simt_isa_pkg.sv
xvlog -sv build/simt_isa_pkg.sv rtl/simt_gpu_pkg.sv \
  rtl/frontend/instruction_decoder.sv \
  rtl/frontend/instruction_memory.sv rtl/frontend/instruction_fetch.sv \
  rtl/register_file/vector_register_file.sv \
  rtl/register_file/predicate_register_file.sv \
  rtl/execute/integer_lane.sv rtl/execute/vector_integer_alu.sv \
  tb/unit/tb_package_smoke.sv tb/unit/tb_instruction_decoder.sv \
  tb/unit/tb_vector_register_file.sv tb/unit/tb_predicate_register_file.sv \
  tb/unit/tb_vector_integer_alu.sv tb/unit/tb_instruction_fetch.sv
xelab tb_package_smoke -s tb_package_smoke_sim
xelab tb_instruction_decoder -s tb_instruction_decoder_sim
xelab tb_vector_register_file -s tb_vector_register_file_sim
xelab tb_predicate_register_file -s tb_predicate_register_file_sim
xelab tb_vector_integer_alu -s tb_vector_integer_alu_sim
xelab tb_instruction_fetch -s tb_instruction_fetch_sim
