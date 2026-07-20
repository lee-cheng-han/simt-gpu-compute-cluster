module instruction_decoder (
  input  logic [31:0] instr_i,
  output logic        legal_o,
  output simt_isa_pkg::opcode_t opcode_o,
  output logic        pred_enable_o,
  output logic        pred_invert_o,
  output logic        guard_exec_o,
  output logic [1:0]  pred_o,
  output logic [3:0]  rd_o,
  output logic [3:0]  ra_o,
  output logic [3:0]  rb_o,
  output logic signed [9:0] imm_o,
  output logic        uses_ra_o,
  output logic        uses_rb_o,
  output logic        writes_gpr_o,
  output logic        writes_pred_o,
  output logic        is_load_o,
  output logic        is_store_o,
  output logic        is_branch_o
);
  import simt_isa_pkg::*;

  logic [5:0] opcode_bits;
  logic [9:0] imm_bits;

  always_comb begin
    opcode_bits  = instr_i[31:26];
    opcode_o     = opcode_t'(opcode_bits);
    pred_enable_o = instr_i[25];
    pred_invert_o = instr_i[24];
    pred_o       = instr_i[23:22];
    rd_o         = instr_i[21:18];
    ra_o         = instr_i[17:14];
    rb_o         = instr_i[13:10];
    imm_bits     = instr_i[9:0];
    imm_o        = $signed(imm_bits);

    legal_o      = 1'b0;
    guard_exec_o = pred_enable_o;
    uses_ra_o    = 1'b0;
    uses_rb_o    = 1'b0;
    writes_gpr_o = 1'b0;
    writes_pred_o = 1'b0;
    is_load_o    = 1'b0;
    is_store_o   = 1'b0;
    is_branch_o  = 1'b0;

    // An unguarded instruction has a canonical zero predicate selector.
    if (pred_enable_o || (!pred_invert_o && pred_o == 2'd0)) begin
      unique case (opcode_bits)
        OP_NOP, OP_BAR, OP_EXIT: legal_o =
          (rd_o == 4'd0 && ra_o == 4'd0 && rb_o == 4'd0 && imm_bits == 10'd0);
        OP_SYNC: legal_o =
          (!pred_enable_o && rd_o == 4'd0 && ra_o == 4'd0 &&
           rb_o == 4'd0 && imm_bits == 10'd0);

        OP_ADD, OP_SUB, OP_MUL, OP_MIN, OP_MAX,
        OP_AND, OP_OR, OP_XOR, OP_SHL, OP_SHR, OP_SAR: begin
          legal_o = (imm_bits == 10'd0);
          uses_ra_o = 1'b1;
          uses_rb_o = 1'b1;
          writes_gpr_o = 1'b1;
        end
        OP_SEL: begin
          legal_o = pred_enable_o && (imm_bits == 10'd0);
          guard_exec_o = 1'b0;
          uses_ra_o = 1'b1;
          uses_rb_o = 1'b1;
          writes_gpr_o = 1'b1;
        end
        OP_NOT, OP_MOV: begin
          legal_o = (rb_o == 4'd0 && imm_bits == 10'd0);
          uses_ra_o = 1'b1;
          writes_gpr_o = 1'b1;
        end
        OP_MOVI: begin
          legal_o = (ra_o == 4'd0 && rb_o == 4'd0);
          writes_gpr_o = 1'b1;
        end
        OP_SETP_EQ, OP_SETP_NE, OP_SETP_LT,
        OP_SETP_LE, OP_SETP_GT, OP_SETP_GE: begin
          legal_o = (rd_o < 4'd4 && imm_bits == 10'd0);
          uses_ra_o = 1'b1;
          uses_rb_o = 1'b1;
          writes_pred_o = 1'b1;
        end
        OP_LD_G, OP_LD_S: begin
          legal_o = (rb_o == 4'd0);
          uses_ra_o = 1'b1;
          writes_gpr_o = 1'b1;
          is_load_o = 1'b1;
        end
        OP_ST_G, OP_ST_S: begin
          legal_o = (rd_o == 4'd0);
          uses_ra_o = 1'b1;
          uses_rb_o = 1'b1;
          is_store_o = 1'b1;
        end
        OP_BRA: begin
          legal_o = (rd_o == 4'd0 && ra_o == 4'd0 && rb_o == 4'd0);
          is_branch_o = 1'b1;
        end
        OP_SSY: begin
          legal_o = (!pred_enable_o && rd_o == 4'd0 &&
                     ra_o == 4'd0 && rb_o == 4'd0);
          is_branch_o = 1'b1;
        end
        OP_S2R: begin
          legal_o = (ra_o == 4'd0 && rb_o == 4'd0 && imm_bits <= 10'd6);
          writes_gpr_o = 1'b1;
        end
        default: legal_o = 1'b0;
      endcase
    end
  end
endmodule
