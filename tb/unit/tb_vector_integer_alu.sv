module tb_vector_integer_alu;
  import simt_isa_pkg::*;
  localparam int unsigned LANES = 8;

  opcode_t lane_opcode, vec_opcode;
  logic lane_active, lane_predicate, lane_pred_result, lane_branch, lane_supported;
  logic [31:0] lane_a, lane_b, lane_special, lane_result, lane_address, lane_store;
  logic signed [9:0] lane_imm;

  logic vec_valid, vec_pred_invert, vec_guard_exec, vec_writes_gpr, vec_writes_pred;
  logic [LANES-1:0] vec_active, vec_predicate, execute_mask, gpr_mask, pred_mask;
  logic [LANES-1:0] predicate_result, branch_condition;
  logic [LANES-1:0][31:0] vec_a, vec_b, vec_special;
  logic [LANES-1:0][31:0] vec_result, memory_address, store_data;
  logic signed [9:0] vec_imm;
  logic unsupported;
  int unsigned checks;

  integer_lane lane_dut (
    .opcode_i(lane_opcode), .active_i(lane_active), .predicate_i(lane_predicate),
    .src_a_i(lane_a), .src_b_i(lane_b), .imm_i(lane_imm),
    .special_i(lane_special), .result_o(lane_result),
    .predicate_result_o(lane_pred_result), .branch_condition_o(lane_branch),
    .memory_address_o(lane_address), .store_data_o(lane_store),
    .operation_supported_o(lane_supported)
  );

  vector_integer_alu vector_dut (
    .valid_i(vec_valid), .opcode_i(vec_opcode), .active_mask_i(vec_active),
    .predicate_mask_i(vec_predicate), .predicate_invert_i(vec_pred_invert),
    .guard_exec_i(vec_guard_exec), .writes_gpr_i(vec_writes_gpr),
    .writes_pred_i(vec_writes_pred), .src_a_i(vec_a), .src_b_i(vec_b),
    .imm_i(vec_imm), .special_i(vec_special), .execute_mask_o(execute_mask),
    .gpr_write_mask_o(gpr_mask), .pred_write_mask_o(pred_mask),
    .result_o(vec_result), .predicate_result_o(predicate_result),
    .branch_condition_o(branch_condition), .memory_address_o(memory_address),
    .store_data_o(store_data), .unsupported_operation_o(unsupported)
  );

  task automatic check_result(
    input opcode_t op,
    input logic [31:0] a,
    input logic [31:0] b,
    input logic signed [9:0] immediate,
    input logic predicate,
    input logic [31:0] special,
    input logic [31:0] expected_result,
    input logic expected_predicate
  );
    lane_opcode = op;
    lane_active = 1'b1;
    lane_predicate = predicate;
    lane_a = a;
    lane_b = b;
    lane_imm = immediate;
    lane_special = special;
    #1;
    checks++;
    if (!lane_supported) $fatal(1, "supported opcode rejected: %0d", op);
    if (lane_result !== expected_result)
      $fatal(1, "result mismatch opcode=%0d got=%08x expected=%08x",
             op, lane_result, expected_result);
    if (lane_pred_result !== expected_predicate)
      $fatal(1, "predicate mismatch opcode=%0d", op);
  endtask

  initial begin
    checks = 0;
    lane_opcode = OP_NOP;
    lane_active = 1'b0;
    lane_predicate = 1'b0;
    lane_a = '0;
    lane_b = '0;
    lane_imm = '0;
    lane_special = '0;

    check_result(OP_ADD, 32'hffff_ffff, 1, 0, 0, 0, 0, 0);
    check_result(OP_SUB, 3, 5, 0, 0, 0, 32'hffff_fffe, 0);
    check_result(OP_MUL, 32'hffff_ffff, 3, 0, 0, 0, 32'hffff_fffd, 0);
    check_result(OP_MIN, 32'hffff_ffff, 1, 0, 0, 0, 32'hffff_ffff, 0);
    check_result(OP_MAX, 32'hffff_ffff, 1, 0, 0, 0, 1, 0);
    check_result(OP_AND, 32'ha5a5_ffff, 32'h0ff0_55aa, 0, 0, 0, 32'h05a0_55aa, 0);
    check_result(OP_OR, 32'ha500_000f, 32'h00f0_00f0, 0, 0, 0, 32'ha5f0_00ff, 0);
    check_result(OP_XOR, 32'hffff_0000, 32'h0f0f_0f0f, 0, 0, 0, 32'hf0f0_0f0f, 0);
    check_result(OP_NOT, 32'h0f0f_55aa, 0, 0, 0, 0, 32'hf0f0_aa55, 0);
    check_result(OP_SHL, 1, 36, 0, 0, 0, 16, 0);
    check_result(OP_SHR, 32'h8000_0000, 31, 0, 0, 0, 1, 0);
    check_result(OP_SAR, 32'h8000_0000, 31, 0, 0, 0, 32'hffff_ffff, 0);
    check_result(OP_MOV, 32'h1234_5678, 0, 0, 0, 0, 32'h1234_5678, 0);
    check_result(OP_MOVI, 0, 0, -10'sd7, 0, 0, 32'hffff_fff9, 0);
    check_result(OP_SEL, 11, 22, 0, 1, 0, 11, 0);
    check_result(OP_SEL, 11, 22, 0, 0, 0, 22, 0);
    check_result(OP_SETP_EQ, 7, 7, 0, 0, 0, 0, 1);
    check_result(OP_SETP_NE, 7, 8, 0, 0, 0, 0, 1);
    check_result(OP_SETP_LT, 32'hffff_ffff, 0, 0, 0, 0, 0, 1);
    check_result(OP_SETP_LE, 5, 5, 0, 0, 0, 0, 1);
    check_result(OP_SETP_GT, 1, 32'hffff_ffff, 0, 0, 0, 0, 1);
    check_result(OP_SETP_GE, 5, 5, 0, 0, 0, 0, 1);
    check_result(OP_S2R, 0, 0, 0, 0, 32'hdead_beef, 32'hdead_beef, 0);

    lane_opcode = OP_LD_G; lane_active = 1; lane_a = 100; lane_b = 32'hfeed_face;
    lane_imm = -10'sd4; #1; checks++;
    if (lane_address != 96 || lane_store != 32'hfeed_face)
      $fatal(1, "memory address/store-data mismatch");
    lane_opcode = OP_BRA; lane_predicate = 1; #1; checks++;
    if (!lane_branch) $fatal(1, "branch condition mismatch");
    lane_active = 0; #1; checks++;
    if (lane_result != 0 || lane_pred_result || lane_branch ||
        lane_address != 0 || lane_store != 0 || !lane_supported)
      $fatal(1, "inactive lane did not suppress outputs");
    lane_opcode = opcode_t'(6'd63); #1; checks++;
    if (lane_supported) $fatal(1, "unsupported opcode accepted");

    vec_valid = 1;
    vec_opcode = OP_ADD;
    vec_active = 8'b1111_0111;
    vec_predicate = 8'b1010_1010;
    vec_pred_invert = 0;
    vec_guard_exec = 1;
    vec_writes_gpr = 1;
    vec_writes_pred = 0;
    vec_imm = 4;
    for (int unsigned lane = 0; lane < LANES; lane++) begin
      vec_a[lane] = lane;
      vec_b[lane] = 100 + lane;
      vec_special[lane] = 32'h1000 + lane;
    end
    #1; checks++;
    if (execute_mask != (vec_active & vec_predicate) || gpr_mask != execute_mask ||
        pred_mask != 0 || unsupported)
      $fatal(1, "predicated vector mask mismatch");
    for (int unsigned lane = 0; lane < LANES; lane++) begin
      checks++;
      if (execute_mask[lane] && vec_result[lane] != 100 + 2*lane)
        $fatal(1, "vector ADD mismatch lane=%0d", lane);
      if (!execute_mask[lane] && vec_result[lane] != 0)
        $fatal(1, "inactive vector lane produced result lane=%0d", lane);
    end

    // SEL consumes the predicate as data selection, not as an execution guard.
    vec_opcode = OP_SEL;
    vec_active = '1;
    vec_guard_exec = 0;
    vec_writes_gpr = 1;
    vec_predicate = 8'b0000_1111;
    #1; checks++;
    if (execute_mask != '1 || gpr_mask != '1) $fatal(1, "SEL masked lanes");
    for (int unsigned lane = 0; lane < LANES; lane++) begin
      checks++;
      if (vec_result[lane] != (vec_predicate[lane] ? vec_a[lane] : vec_b[lane]))
        $fatal(1, "SEL result mismatch lane=%0d", lane);
    end

    vec_opcode = OP_SETP_LT;
    vec_writes_gpr = 0;
    vec_writes_pred = 1;
    vec_guard_exec = 0;
    #1; checks++;
    if (pred_mask != vec_active || gpr_mask != 0 || predicate_result != '1)
      $fatal(1, "predicate vector result mismatch");

    vec_opcode = OP_BRA;
    vec_predicate = 8'b0101_1010;
    vec_pred_invert = 1'b0;
    #1; checks++;
    if (branch_condition != vec_predicate) $fatal(1, "branch vector condition mismatch");

    vec_opcode = OP_ST_G;
    vec_writes_pred = 0;
    vec_imm = -10'sd4;
    #1;
    for (int unsigned lane = 0; lane < LANES; lane++) begin
      checks++;
      if (memory_address[lane] != vec_a[lane] - 4 || store_data[lane] != vec_b[lane])
        $fatal(1, "vector memory output mismatch lane=%0d", lane);
    end

    vec_valid = 0; #1; checks++;
    if (execute_mask != 0 || gpr_mask != 0 || pred_mask != 0 || unsupported)
      $fatal(1, "invalid vector operation generated side effects");
    vec_valid = 1; vec_opcode = opcode_t'(6'd63); #1; checks++;
    if (!unsupported) $fatal(1, "unsupported vector opcode not reported");

    $display("PASS tb_vector_integer_alu checks=%0d", checks);
    $finish;
  end
endmodule
