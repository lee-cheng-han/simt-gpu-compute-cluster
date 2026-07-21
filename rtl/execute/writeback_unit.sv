module writeback_unit #(
  parameter int unsigned LANES = 8,
  parameter int unsigned XLEN = 32,
  parameter int unsigned WARP_W = 2,
  parameter int unsigned REG_W = 4,
  parameter int unsigned PRED_W = 2,
  parameter int unsigned PC_W = 32
) (
  input  logic clk,
  input  logic rst,
  input  logic flush_i,

  input  logic                         result_valid_i,
  output logic                         result_ready_o,
  input  logic [WARP_W-1:0]            result_warp_i,
  input  logic [PC_W-1:0]              result_pc_i,
  input  logic [REG_W-1:0]             result_rd_i,
  input  logic [PRED_W-1:0]            result_pred_i,
  input  logic                         result_writes_gpr_i,
  input  logic                         result_writes_pred_i,
  input  logic [LANES-1:0]             result_gpr_mask_i,
  input  logic [LANES-1:0]             result_pred_mask_i,
  input  logic [LANES-1:0][XLEN-1:0]   result_data_i,
  input  logic [LANES-1:0]             result_predicate_i,

  output logic                         commit_valid_o,
  input  logic                         commit_ready_i,
  output logic [WARP_W-1:0]            commit_warp_o,
  output logic [PC_W-1:0]              commit_pc_o,

  output logic                         gpr_write_valid_o,
  output logic [WARP_W-1:0]            gpr_write_warp_o,
  output logic [REG_W-1:0]             gpr_write_reg_o,
  output logic [LANES-1:0]             gpr_write_mask_o,
  output logic [LANES-1:0][XLEN-1:0]   gpr_write_data_o,

  output logic                         pred_write_valid_o,
  output logic [WARP_W-1:0]            pred_write_warp_o,
  output logic [PRED_W-1:0]            pred_write_pred_o,
  output logic [LANES-1:0]             pred_write_mask_o,
  output logic [LANES-1:0]             pred_write_data_o
);
  logic full_q;
  logic [WARP_W-1:0] warp_q;
  logic [PC_W-1:0] pc_q;
  logic [REG_W-1:0] rd_q;
  logic [PRED_W-1:0] pred_q;
  logic writes_gpr_q, writes_pred_q;
  logic [LANES-1:0] gpr_mask_q, pred_mask_q;
  logic [LANES-1:0][XLEN-1:0] data_q;
  logic [LANES-1:0] predicate_q;
  logic commit_fire;

  always_comb begin
    commit_valid_o = full_q;
    commit_warp_o = warp_q;
    commit_pc_o = pc_q;
    commit_fire = commit_valid_o && commit_ready_i;
    result_ready_o = !full_q || commit_ready_i;

    gpr_write_valid_o = commit_fire && writes_gpr_q && (|gpr_mask_q);
    gpr_write_warp_o = warp_q;
    gpr_write_reg_o = rd_q;
    gpr_write_mask_o = gpr_mask_q;
    gpr_write_data_o = data_q;

    pred_write_valid_o = commit_fire && writes_pred_q && (|pred_mask_q);
    pred_write_warp_o = warp_q;
    pred_write_pred_o = pred_q;
    pred_write_mask_o = pred_mask_q;
    pred_write_data_o = predicate_q;
  end

  always_ff @(posedge clk) begin
    if (rst || flush_i) begin
      full_q <= 1'b0;
      warp_q <= '0;
      pc_q <= '0;
      rd_q <= '0;
      pred_q <= '0;
      writes_gpr_q <= 1'b0;
      writes_pred_q <= 1'b0;
      gpr_mask_q <= '0;
      pred_mask_q <= '0;
      data_q <= '0;
      predicate_q <= '0;
    end else if (result_ready_o) begin
      full_q <= result_valid_i;
      if (result_valid_i) begin
        warp_q <= result_warp_i;
        pc_q <= result_pc_i;
        rd_q <= result_rd_i;
        pred_q <= result_pred_i;
        writes_gpr_q <= result_writes_gpr_i;
        writes_pred_q <= result_writes_pred_i;
        gpr_mask_q <= result_gpr_mask_i;
        pred_mask_q <= result_pred_mask_i;
        data_q <= result_data_i;
        predicate_q <= result_predicate_i;
      end
    end
  end

`ifndef SYNTHESIS
  property p_commit_stable;
    @(posedge clk) disable iff (rst || flush_i)
      commit_valid_o && !commit_ready_i
      |=> $stable(commit_valid_o) && $stable(commit_warp_o) &&
          $stable(commit_pc_o) && $stable(gpr_write_warp_o) &&
          $stable(gpr_write_reg_o) && $stable(gpr_write_mask_o) &&
          $stable(gpr_write_data_o) && $stable(pred_write_pred_o) &&
          $stable(pred_write_mask_o) && $stable(pred_write_data_o);
  endproperty
  assert property (p_commit_stable)
    else $error("writeback payload changed under backpressure");

  always_comb begin
    assert (!(gpr_write_valid_o && !(|gpr_write_mask_o)))
      else $error("empty GPR write reached commit");
    assert (!(pred_write_valid_o && !(|pred_write_mask_o)))
      else $error("empty predicate write reached commit");
  end
`endif
endmodule
