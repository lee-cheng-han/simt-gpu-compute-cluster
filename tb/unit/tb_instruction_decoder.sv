module tb_instruction_decoder;
  import simt_isa_pkg::*;

  logic [31:0] instr;
  logic legal, pred_enable, pred_invert, guard_exec;
  logic [1:0] pred;
  logic [3:0] rd, ra, rb;
  logic signed [9:0] imm;
  logic uses_ra, uses_rb, writes_gpr, writes_pred;
  logic is_load, is_store, is_branch;
  opcode_t opcode;
  int unsigned checks;

  instruction_decoder dut (
    .instr_i(instr), .legal_o(legal), .opcode_o(opcode),
    .pred_enable_o(pred_enable), .pred_invert_o(pred_invert),
    .guard_exec_o(guard_exec), .pred_o(pred), .rd_o(rd), .ra_o(ra),
    .rb_o(rb), .imm_o(imm), .uses_ra_o(uses_ra), .uses_rb_o(uses_rb),
    .writes_gpr_o(writes_gpr), .writes_pred_o(writes_pred),
    .is_load_o(is_load), .is_store_o(is_store), .is_branch_o(is_branch)
  );

  function automatic logic [31:0] enc(
    input logic [5:0] op,
    input logic pe,
    input logic pi,
    input logic [1:0] p,
    input logic [3:0] d,
    input logic [3:0] a,
    input logic [3:0] b,
    input logic [9:0] i
  );
    return {op, pe, pi, p, d, a, b, i};
  endfunction

  task automatic expect_legal(input logic [31:0] value, input opcode_t expected);
    instr = value;
    #1;
    checks++;
    if (!legal || opcode != expected)
      $fatal(1, "expected legal opcode %0d, instr=%08x", expected, value);
  endtask

  task automatic expect_illegal(input logic [31:0] value);
    instr = value;
    #1;
    checks++;
    if (legal) $fatal(1, "expected illegal encoding %08x", value);
  endtask

  initial begin
    checks = 0;
    // Exercise every allocated opcode with a canonical encoding.
    expect_legal(enc(OP_NOP,0,0,0,0,0,0,0), OP_NOP);
    expect_legal(enc(OP_ADD,0,0,0,1,2,3,0), OP_ADD);
    expect_legal(enc(OP_SUB,0,0,0,1,2,3,0), OP_SUB);
    expect_legal(enc(OP_MUL,0,0,0,1,2,3,0), OP_MUL);
    expect_legal(enc(OP_MIN,0,0,0,1,2,3,0), OP_MIN);
    expect_legal(enc(OP_MAX,0,0,0,1,2,3,0), OP_MAX);
    expect_legal(enc(OP_AND,0,0,0,1,2,3,0), OP_AND);
    expect_legal(enc(OP_OR,0,0,0,1,2,3,0), OP_OR);
    expect_legal(enc(OP_XOR,0,0,0,1,2,3,0), OP_XOR);
    expect_legal(enc(OP_NOT,0,0,0,1,2,0,0), OP_NOT);
    expect_legal(enc(OP_SHL,0,0,0,1,2,3,0), OP_SHL);
    expect_legal(enc(OP_SHR,0,0,0,1,2,3,0), OP_SHR);
    expect_legal(enc(OP_SAR,0,0,0,1,2,3,0), OP_SAR);
    expect_legal(enc(OP_MOV,0,0,0,1,2,0,0), OP_MOV);
    expect_legal(enc(OP_MOVI,0,0,0,1,0,0,10'h3ff), OP_MOVI);
    expect_legal(enc(OP_SEL,1,0,2,1,2,3,0), OP_SEL);
    expect_legal(enc(OP_SETP_EQ,0,0,0,2,1,3,0), OP_SETP_EQ);
    expect_legal(enc(OP_SETP_NE,0,0,0,2,1,3,0), OP_SETP_NE);
    expect_legal(enc(OP_SETP_LT,0,0,0,2,1,3,0), OP_SETP_LT);
    expect_legal(enc(OP_SETP_LE,0,0,0,2,1,3,0), OP_SETP_LE);
    expect_legal(enc(OP_SETP_GT,0,0,0,2,1,3,0), OP_SETP_GT);
    expect_legal(enc(OP_SETP_GE,0,0,0,2,1,3,0), OP_SETP_GE);
    expect_legal(enc(OP_LD_G,0,0,0,1,2,0,4), OP_LD_G);
    expect_legal(enc(OP_ST_G,0,0,0,0,2,3,4), OP_ST_G);
    expect_legal(enc(OP_LD_S,0,0,0,1,2,0,4), OP_LD_S);
    expect_legal(enc(OP_ST_S,0,0,0,0,2,3,4), OP_ST_S);
    expect_legal(enc(OP_BRA,1,1,3,0,0,0,10'h3ff), OP_BRA);
    expect_legal(enc(OP_SSY,0,0,0,0,0,0,7), OP_SSY);
    expect_legal(enc(OP_BAR,0,0,0,0,0,0,0), OP_BAR);
    expect_legal(enc(OP_S2R,0,0,0,1,0,0,6), OP_S2R);
    expect_legal(enc(OP_EXIT,1,0,1,0,0,0,0), OP_EXIT);
    expect_legal(enc(OP_SYNC,0,0,0,0,0,0,0), OP_SYNC);

    instr = enc(OP_ADD,1,1,2,1,2,3,0); #1;
    if (!guard_exec || !pred_enable || !pred_invert || pred != 2'd2 ||
        rd != 4'd1 || ra != 4'd2 || rb != 4'd3 ||
        !uses_ra || !uses_rb || !writes_gpr)
      $fatal(1, "guarded ADD metadata mismatch");
    checks++;

    instr = enc(OP_SEL,1,0,2,1,2,3,0); #1;
    if (guard_exec || !uses_ra || !uses_rb || !writes_gpr)
      $fatal(1, "SEL selector metadata mismatch");
    checks++;

    instr = enc(OP_LD_G,0,0,0,1,2,0,10'h3fc); #1;
    if (!is_load || imm != -10'sd4) $fatal(1, "load metadata mismatch");
    checks++;

    instr = enc(OP_ST_S,0,0,0,0,2,3,0); #1;
    if (!is_store || !uses_ra || !uses_rb) $fatal(1, "store metadata mismatch");
    checks++;

    instr = enc(OP_BRA,0,0,0,0,0,0,1); #1;
    if (!is_branch) $fatal(1, "branch metadata mismatch");
    checks++;

    instr = enc(OP_SETP_GE,0,0,0,2,1,3,0); #1;
    if (!writes_pred || writes_gpr) $fatal(1, "predicate metadata mismatch");
    checks++;

    // Representative violations of every canonical-field rule.
    expect_illegal(enc(6'd32,0,0,0,0,0,0,0));
    expect_illegal(enc(OP_ADD,0,0,0,1,2,3,1));
    expect_illegal(enc(OP_MOV,0,0,0,1,2,1,0));
    expect_illegal(enc(OP_MOVI,0,0,0,1,1,0,0));
    expect_illegal(enc(OP_SEL,0,0,0,1,2,3,0));
    expect_illegal(enc(OP_SETP_EQ,0,0,0,4,1,2,0));
    expect_illegal(enc(OP_LD_G,0,0,0,1,2,1,0));
    expect_illegal(enc(OP_ST_G,0,0,0,1,2,3,0));
    expect_illegal(enc(OP_SSY,1,0,0,0,0,0,0));
    expect_illegal(enc(OP_SYNC,1,0,0,0,0,0,0));
    expect_illegal(enc(OP_S2R,0,0,0,1,0,0,7));
    expect_illegal(enc(OP_NOP,0,1,0,0,0,0,0));

    $display("PASS tb_instruction_decoder checks=%0d", checks);
    $finish;
  end
endmodule
