module single_warp_core #(
  parameter int unsigned IMEM_WORDS = 64,
  parameter int unsigned IMEM_ADDR_W = $clog2(IMEM_WORDS)
) (
  input logic clk, input logic rst, input logic clear_i,
  input logic prog_valid_i, input logic [IMEM_ADDR_W-1:0] prog_addr_i,
  input logic [31:0] prog_data_i,
  input logic launch_valid_i, output logic launch_ready_o,
  input logic [31:0] launch_pc_i,
  output logic running_o, output logic done_o, output logic fault_o,
  output logic [31:0] fault_pc_o,
  output logic commit_valid_o, output simt_gpu_pkg::completion_record_t commit_o
);
  import simt_gpu_pkg::*;
  import simt_isa_pkg::*;

  logic imem_fv; logic [IMEM_ADDR_W-1:0] imem_fa; logic [31:0] imem_fd;
  logic fetch_v, fetch_r, fetch_running, fetch_fault;
  logic [31:0] fetch_pc, fetch_insn, fetch_fault_pc;
  logic legal, pred_enable, pred_invert, guard_exec;
  opcode_t opcode; logic [1:0] pred_index; logic [3:0] rd, ra, rb;
  logic signed [9:0] imm; logic uses_ra, uses_rb, writes_gpr, writes_pred;
  logic is_load, is_store, is_branch;
  logic supported, issue_fire, scoreboard_ready, alu_result_ready, queue_ready;
  logic [REGS_PER_THREAD-1:0] gpr_sources;
  logic [PREDS_PER_THREAD-1:0] pred_sources;
  logic [INSTRUCTION_SEQUENCE_WIDTH-1:0] sequence_q;
  logic [KERNEL_EPOCH_WIDTH-1:0] epoch_q;
  lane_mask_t active_mask_q, pred_mask, execute_mask, gpr_mask, pred_write_mask;
  word_t [LANES-1:0] src_a, src_b, special, alu_result;
  lane_mask_t alu_pred_result, branch_condition;
  word_t [LANES-1:0] memory_address, store_data;
  logic alu_unsupported, stale_cancel;
  logic completion_v; completion_record_t completion;
  logic [1:0] completion_occupancy;
  logic wb_commit_v, wb_gpr_v, wb_pred_v, clear_gpr_v, clear_pred_v;
  logic [WARP_ID_WIDTH-1:0] wb_gpr_warp, wb_pred_warp, clear_warp;
  logic [REG_INDEX_WIDTH-1:0] wb_gpr_reg, clear_gpr;
  logic [PRED_INDEX_WIDTH-1:0] wb_pred_index, clear_pred;
  lane_mask_t wb_gpr_mask, wb_pred_mask, wb_pred_data;
  word_t [LANES-1:0] wb_gpr_data;
  logic [KERNEL_EPOCH_WIDTH-1:0] clear_epoch;
  logic [INSTRUCTION_SEQUENCE_WIDTH-1:0] clear_sequence;
  logic launched_q, done_q, fault_q;
  logic integration_fault;
  logic [WARPS-1:0][REGS_PER_THREAD-1:0] gpr_pending;
  logic [WARPS-1:0][PREDS_PER_THREAD-1:0] pred_pending;

  instruction_memory #(.WORDS(IMEM_WORDS)) imem_u (
    .clk(clk), .prog_valid_i(prog_valid_i && launch_ready_o),
    .prog_addr_i(prog_addr_i), .prog_data_i(prog_data_i),
    .fetch_valid_i(imem_fv), .fetch_addr_i(imem_fa), .fetch_data_o(imem_fd));
  instruction_fetch #(.IMEM_WORDS(IMEM_WORDS)) fetch_u (
    .clk(clk), .rst(rst), .clear_fault_i(clear_i),
    .start_valid_i(launch_valid_i), .start_ready_o(launch_ready_o),
    .start_pc_i(launch_pc_i), .halt_i(fault_q || integration_fault ||
      (issue_fire && opcode == OP_EXIT && ((active_mask_q & ~execute_mask) == '0))),
    .redirect_valid_i(1'b0), .redirect_pc_i('0),
    .imem_fetch_valid_o(imem_fv), .imem_fetch_addr_o(imem_fa),
    .imem_fetch_data_i(imem_fd), .fetch_valid_o(fetch_v),
    .fetch_ready_i(fetch_r), .fetch_pc_o(fetch_pc), .fetch_instr_o(fetch_insn),
    .running_o(fetch_running), .fault_valid_o(fetch_fault),
    .fault_pc_o(fetch_fault_pc));
  instruction_decoder decoder_u (
    .instr_i(fetch_insn), .legal_o(legal), .opcode_o(opcode),
    .pred_enable_o(pred_enable), .pred_invert_o(pred_invert),
    .guard_exec_o(guard_exec), .pred_o(pred_index), .rd_o(rd), .ra_o(ra),
    .rb_o(rb), .imm_o(imm), .uses_ra_o(uses_ra), .uses_rb_o(uses_rb),
    .writes_gpr_o(writes_gpr), .writes_pred_o(writes_pred),
    .is_load_o(is_load), .is_store_o(is_store), .is_branch_o(is_branch));

  always_comb begin
    supported = legal && !is_load && !is_store && !is_branch &&
                opcode != OP_MUL && opcode != OP_BAR && opcode != OP_SYNC;
    gpr_sources = '0; pred_sources = '0;
    if (uses_ra) gpr_sources[ra] = 1'b1;
    if (uses_rb) gpr_sources[rb] = 1'b1;
    if (pred_enable) pred_sources[pred_index] = 1'b1;
    integration_fault = fetch_v && (!legal || !supported);
    fetch_r = fetch_v && supported && scoreboard_ready && alu_result_ready && !fault_q;
    issue_fire = fetch_v && fetch_r;
    running_o = fetch_running || (launched_q && !done_q && !fault_q);
    done_o = done_q; fault_o = fault_q || fetch_fault;
    fault_pc_o = fetch_fault ? fetch_fault_pc : fetch_pc;
    commit_valid_o = wb_commit_v;
  end

  vector_register_file gpr_u (.clk(clk), .rst(rst), .read_valid_i(fetch_v),
    .read_warp_i('0), .read_ra_i(ra), .read_rb_i(rb), .read_a_o(src_a),
    .read_b_o(src_b), .write_valid_i(wb_gpr_v), .write_warp_i(wb_gpr_warp),
    .write_reg_i(wb_gpr_reg), .write_lane_mask_i(wb_gpr_mask),
    .write_data_i(wb_gpr_data));
  predicate_register_file pred_u (.clk(clk), .rst(rst),
    .read_valid_i(fetch_v && pred_enable), .read_warp_i('0),
    .read_pred_i(pred_index), .read_mask_o(pred_mask),
    .write_valid_i(wb_pred_v), .write_warp_i(wb_pred_warp),
    .write_pred_i(wb_pred_index), .write_lane_mask_i(wb_pred_mask),
    .write_data_i(wb_pred_data));
  for (genvar lane = 0; lane < LANES; lane++) begin : gen_special
    always_comb begin
      special[lane] = '0;
      case (imm)
        10'sd3: special[lane] = word_t'(lane);
        10'sd5: special[lane] = LANES;
        default: special[lane] = '0;
      endcase
    end
  end
  vector_integer_alu alu_u (.valid_i(issue_fire), .opcode_i(opcode),
    .active_mask_i(active_mask_q), .predicate_mask_i(pred_mask),
    .predicate_invert_i(pred_invert), .guard_exec_i(guard_exec),
    .writes_gpr_i(writes_gpr), .writes_pred_i(writes_pred),
    .src_a_i(src_a), .src_b_i(src_b), .imm_i(imm), .special_i(special),
    .execute_mask_o(execute_mask), .gpr_write_mask_o(gpr_mask),
    .pred_write_mask_o(pred_write_mask), .result_o(alu_result),
    .predicate_result_o(alu_pred_result), .branch_condition_o(branch_condition),
    .memory_address_o(memory_address), .store_data_o(store_data),
    .unsupported_operation_o(alu_unsupported));
  dependency_scoreboard scoreboard_u (.clk(clk), .rst(rst), .clear_i(clear_i),
    .issue_warp_i('0), .issue_gpr_sources_i(gpr_sources),
    .issue_gpr_dest_valid_i(writes_gpr), .issue_gpr_dest_i(rd),
    .issue_pred_sources_i(pred_sources), .issue_pred_dest_valid_i(writes_pred),
    .issue_pred_dest_i(rd[1:0]), .issue_epoch_i(epoch_q),
    .issue_sequence_i(sequence_q), .issue_ready_o(scoreboard_ready),
    .issue_accept_i(issue_fire), .clear_gpr_valid_i(clear_gpr_v),
    .clear_pred_valid_i(clear_pred_v), .clear_epoch_i(clear_epoch),
    .clear_warp_i(clear_warp), .clear_sequence_i(clear_sequence),
    .clear_gpr_i(clear_gpr), .clear_pred_i(clear_pred),
    .gpr_pending_o(gpr_pending), .pred_pending_o(pred_pending));
  alu_completion_stage completion_u (.clk(clk), .rst(rst), .flush_i(clear_i || fault_q),
    .result_valid_i(issue_fire), .result_ready_o(alu_result_ready),
    .epoch_i(epoch_q), .warp_id_i('0), .sequence_number_i(sequence_q),
    .pc_i(fetch_pc), .instruction_i(fetch_insn), .active_mask_i(active_mask_q),
    .write_mask_i(execute_mask), .writes_gpr_i(writes_gpr), .gpr_dst_i(rd),
    .gpr_mask_i(gpr_mask), .gpr_data_i(alu_result), .writes_pred_i(writes_pred),
    .pred_dst_i(rd[1:0]), .pred_mask_i(pred_write_mask),
    .pred_data_i(alu_pred_result), .completion_valid_o(completion_v),
    .completion_ready_i(queue_ready), .completion_o(completion),
    .occupancy_o(completion_occupancy));
  architectural_writeback wb_u (.fatal_i(fault_q), .current_epoch_i(epoch_q),
    .completion_valid_i(completion_v), .completion_ready_o(queue_ready),
    .completion_i(completion), .commit_valid_o(wb_commit_v), .commit_ready_i(1'b1),
    .commit_o(commit_o), .stale_cancel_o(stale_cancel),
    .gpr_write_valid_o(wb_gpr_v), .gpr_write_warp_o(wb_gpr_warp),
    .gpr_write_reg_o(wb_gpr_reg), .gpr_write_mask_o(wb_gpr_mask),
    .gpr_write_data_o(wb_gpr_data), .pred_write_valid_o(wb_pred_v),
    .pred_write_warp_o(wb_pred_warp), .pred_write_pred_o(wb_pred_index),
    .pred_write_mask_o(wb_pred_mask), .pred_write_data_o(wb_pred_data),
    .clear_gpr_valid_o(clear_gpr_v), .clear_pred_valid_o(clear_pred_v),
    .clear_epoch_o(clear_epoch), .clear_warp_o(clear_warp),
    .clear_sequence_o(clear_sequence), .clear_gpr_o(clear_gpr),
    .clear_pred_o(clear_pred));

  always_ff @(posedge clk) begin
    if (rst) begin epoch_q <= '0; sequence_q <= '0; active_mask_q <= '0;
      launched_q <= 1'b0; done_q <= 1'b0; fault_q <= 1'b0; end
    else if (clear_i) begin epoch_q <= epoch_q + 1'b1; sequence_q <= '0;
      active_mask_q <= '0; launched_q <= 1'b0; done_q <= 1'b0; fault_q <= 1'b0; end
    else begin
      if (launch_valid_i && launch_ready_o) begin active_mask_q <= '1;
        sequence_q <= '0; launched_q <= 1'b1; done_q <= 1'b0; end
      if (integration_fault || fetch_fault) fault_q <= 1'b1;
      if (issue_fire) begin
        sequence_q <= sequence_q + 1'b1;
        if (opcode == OP_EXIT) active_mask_q <= active_mask_q & ~execute_mask;
      end
      if (launched_q && active_mask_q == '0 && !fetch_running &&
          !completion_v && completion_occupancy == 0 &&
          gpr_pending == '0 && pred_pending == '0 && !fault_q)
        done_q <= 1'b1;
    end
  end

`ifndef SYNTHESIS
  initial begin
    assert (SIMT_STACK_DEPTH == 8 && SCRATCHPAD_BYTES == 4096 &&
            SHMEM_BYTES == 2048 && MAX_MEMORY_OPS == 4 &&
            MULTIPLIER_LATENCY == 3);
  end
  always_comb begin
    if (issue_fire) begin
      assert (!alu_unsupported);
      assert (branch_condition == '0 && memory_address == '0 && store_data == '0);
    end
    assert (!stale_cancel);
  end
`endif
endmodule
