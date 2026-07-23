module dependency_scoreboard (
  input  logic                                                clk,
  input  logic                                                rst,
  input  logic                                                clear_i,

  input  logic [simt_gpu_pkg::WARP_ID_WIDTH-1:0]             issue_warp_i,
  input  logic [simt_gpu_pkg::REGS_PER_THREAD-1:0]           issue_gpr_sources_i,
  input  logic                                                issue_gpr_dest_valid_i,
  input  logic [simt_gpu_pkg::REG_INDEX_WIDTH-1:0]           issue_gpr_dest_i,
  input  logic [simt_gpu_pkg::PREDS_PER_THREAD-1:0]          issue_pred_sources_i,
  input  logic                                                issue_pred_dest_valid_i,
  input  logic [simt_gpu_pkg::PRED_INDEX_WIDTH-1:0]          issue_pred_dest_i,
  input  logic [simt_gpu_pkg::KERNEL_EPOCH_WIDTH-1:0]        issue_epoch_i,
  input  logic [simt_gpu_pkg::INSTRUCTION_SEQUENCE_WIDTH-1:0]
                                                               issue_sequence_i,
  output logic                                                issue_ready_o,
  input  logic                                                issue_accept_i,

  input  logic                                                clear_gpr_valid_i,
  input  logic                                                clear_pred_valid_i,
  input  logic [simt_gpu_pkg::KERNEL_EPOCH_WIDTH-1:0]        clear_epoch_i,
  input  logic [simt_gpu_pkg::WARP_ID_WIDTH-1:0]             clear_warp_i,
  input  logic [simt_gpu_pkg::INSTRUCTION_SEQUENCE_WIDTH-1:0]
                                                               clear_sequence_i,
  input  logic [simt_gpu_pkg::REG_INDEX_WIDTH-1:0]           clear_gpr_i,
  input  logic [simt_gpu_pkg::PRED_INDEX_WIDTH-1:0]          clear_pred_i,

  output logic [simt_gpu_pkg::WARPS-1:0]
               [simt_gpu_pkg::REGS_PER_THREAD-1:0]           gpr_pending_o,
  output logic [simt_gpu_pkg::WARPS-1:0]
               [simt_gpu_pkg::PREDS_PER_THREAD-1:0]          pred_pending_o
);
  import simt_gpu_pkg::*;

  logic [WARPS-1:0][REGS_PER_THREAD-1:0] gpr_pending_q;
  logic [WARPS-1:0][PREDS_PER_THREAD-1:0] pred_pending_q;
  logic [KERNEL_EPOCH_WIDTH-1:0]
        gpr_owner_epoch_q [WARPS][REGS_PER_THREAD];
  logic [INSTRUCTION_SEQUENCE_WIDTH-1:0]
        gpr_owner_sequence_q [WARPS][REGS_PER_THREAD];
  logic [KERNEL_EPOCH_WIDTH-1:0]
        pred_owner_epoch_q [WARPS][PREDS_PER_THREAD];
  logic [INSTRUCTION_SEQUENCE_WIDTH-1:0]
        pred_owner_sequence_q [WARPS][PREDS_PER_THREAD];

  logic gpr_clear_match;
  logic pred_clear_match;
  logic [REGS_PER_THREAD-1:0] effective_gpr_pending;
  logic gpr_source_hazard;
  logic gpr_dest_hazard;
  logic pred_source_hazard;
  logic pred_dest_hazard;

  always_comb begin
    gpr_clear_match = clear_gpr_valid_i &&
                      gpr_pending_q[clear_warp_i][clear_gpr_i] &&
                      gpr_owner_epoch_q[clear_warp_i][clear_gpr_i] ==
                        clear_epoch_i &&
                      gpr_owner_sequence_q[clear_warp_i][clear_gpr_i] ==
                        clear_sequence_i;
    pred_clear_match = clear_pred_valid_i &&
                       pred_pending_q[clear_warp_i][clear_pred_i] &&
                       pred_owner_epoch_q[clear_warp_i][clear_pred_i] ==
                         clear_epoch_i &&
                       pred_owner_sequence_q[clear_warp_i][clear_pred_i] ==
                         clear_sequence_i;

    // A matching GPR commit can satisfy a source or release a destination in
    // the same cycle because the vector register file forwards accepted writes.
    effective_gpr_pending = gpr_pending_q[issue_warp_i];
    if (gpr_clear_match && clear_warp_i == issue_warp_i)
      effective_gpr_pending[clear_gpr_i] = 1'b0;

    gpr_source_hazard = |(effective_gpr_pending & issue_gpr_sources_i);
    gpr_dest_hazard = issue_gpr_dest_valid_i &&
                      effective_gpr_pending[issue_gpr_dest_i];

    // Predicate state has no forwarding. Readers and writers remain blocked
    // throughout the commit cycle and become eligible on the following cycle.
    pred_source_hazard = |(pred_pending_q[issue_warp_i] &
                           issue_pred_sources_i);
    pred_dest_hazard = issue_pred_dest_valid_i &&
                       pred_pending_q[issue_warp_i][issue_pred_dest_i];

    issue_ready_o = !rst && !clear_i && !gpr_source_hazard &&
                    !gpr_dest_hazard && !pred_source_hazard &&
                    !pred_dest_hazard;
    gpr_pending_o = gpr_pending_q;
    pred_pending_o = pred_pending_q;
  end

  always_ff @(posedge clk) begin
    if (rst || clear_i) begin
      gpr_pending_q <= '0;
      pred_pending_q <= '0;
      for (int unsigned warp = 0; warp < WARPS; warp++) begin
        for (int unsigned reg_index = 0;
             reg_index < REGS_PER_THREAD; reg_index++) begin
          gpr_owner_epoch_q[warp][reg_index] <= '0;
          gpr_owner_sequence_q[warp][reg_index] <= '0;
        end
        for (int unsigned pred_index = 0;
             pred_index < PREDS_PER_THREAD; pred_index++) begin
          pred_owner_epoch_q[warp][pred_index] <= '0;
          pred_owner_sequence_q[warp][pred_index] <= '0;
        end
      end
    end else begin
      if (gpr_clear_match)
        gpr_pending_q[clear_warp_i][clear_gpr_i] <= 1'b0;
      if (pred_clear_match)
        pred_pending_q[clear_warp_i][clear_pred_i] <= 1'b0;

      if (issue_accept_i && issue_gpr_dest_valid_i) begin
        gpr_pending_q[issue_warp_i][issue_gpr_dest_i] <= 1'b1;
        gpr_owner_epoch_q[issue_warp_i][issue_gpr_dest_i] <= issue_epoch_i;
        gpr_owner_sequence_q[issue_warp_i][issue_gpr_dest_i] <=
          issue_sequence_i;
      end
      if (issue_accept_i && issue_pred_dest_valid_i) begin
        pred_pending_q[issue_warp_i][issue_pred_dest_i] <= 1'b1;
        pred_owner_epoch_q[issue_warp_i][issue_pred_dest_i] <= issue_epoch_i;
        pred_owner_sequence_q[issue_warp_i][issue_pred_dest_i] <=
          issue_sequence_i;
      end
    end
  end

`ifndef SYNTHESIS
  property p_issue_only_when_ready;
    @(posedge clk) disable iff (rst || clear_i)
      issue_accept_i |-> issue_ready_o;
  endproperty
  assert property (p_issue_only_when_ready)
    else $error("scoreboard accepted an instruction with a dependency hazard");
`endif
endmodule
