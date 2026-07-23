module tb_dependency_scoreboard;
  import simt_gpu_pkg::*;

  logic clk = 1'b0;
  logic rst;
  logic clear;
  logic [WARP_ID_WIDTH-1:0] issue_warp;
  logic [REGS_PER_THREAD-1:0] issue_gpr_sources;
  logic issue_gpr_dest_valid;
  logic [REG_INDEX_WIDTH-1:0] issue_gpr_dest;
  logic [PREDS_PER_THREAD-1:0] issue_pred_sources;
  logic issue_pred_dest_valid;
  logic [PRED_INDEX_WIDTH-1:0] issue_pred_dest;
  logic [KERNEL_EPOCH_WIDTH-1:0] issue_epoch;
  logic [INSTRUCTION_SEQUENCE_WIDTH-1:0] issue_sequence;
  logic issue_ready;
  logic issue_accept;
  logic clear_gpr_valid;
  logic clear_pred_valid;
  logic [KERNEL_EPOCH_WIDTH-1:0] clear_epoch;
  logic [WARP_ID_WIDTH-1:0] clear_warp;
  logic [INSTRUCTION_SEQUENCE_WIDTH-1:0] clear_sequence;
  logic [REG_INDEX_WIDTH-1:0] clear_gpr;
  logic [PRED_INDEX_WIDTH-1:0] clear_pred;
  logic [WARPS-1:0][REGS_PER_THREAD-1:0] gpr_pending;
  logic [WARPS-1:0][PREDS_PER_THREAD-1:0] pred_pending;
  int unsigned checks;

  always #5 clk <= ~clk;

  dependency_scoreboard dut (
    .clk(clk), .rst(rst), .clear_i(clear),
    .issue_warp_i(issue_warp), .issue_gpr_sources_i(issue_gpr_sources),
    .issue_gpr_dest_valid_i(issue_gpr_dest_valid),
    .issue_gpr_dest_i(issue_gpr_dest),
    .issue_pred_sources_i(issue_pred_sources),
    .issue_pred_dest_valid_i(issue_pred_dest_valid),
    .issue_pred_dest_i(issue_pred_dest), .issue_epoch_i(issue_epoch),
    .issue_sequence_i(issue_sequence), .issue_ready_o(issue_ready),
    .issue_accept_i(issue_accept), .clear_gpr_valid_i(clear_gpr_valid),
    .clear_pred_valid_i(clear_pred_valid), .clear_epoch_i(clear_epoch),
    .clear_warp_i(clear_warp), .clear_sequence_i(clear_sequence),
    .clear_gpr_i(clear_gpr), .clear_pred_i(clear_pred),
    .gpr_pending_o(gpr_pending), .pred_pending_o(pred_pending)
  );

  task automatic clear_query;
    issue_gpr_sources = '0;
    issue_gpr_dest_valid = 1'b0;
    issue_gpr_dest = '0;
    issue_pred_sources = '0;
    issue_pred_dest_valid = 1'b0;
    issue_pred_dest = '0;
  endtask

  task automatic accept_issue;
    @(negedge clk);
    if (!issue_ready) $fatal(1, "scoreboard unexpectedly blocked issue");
    issue_accept = 1'b1;
    @(posedge clk);
    #1;
    issue_accept = 1'b0;
  endtask

  initial begin
    rst = 1'b1;
    clear = 1'b0;
    issue_warp = '0;
    issue_epoch = '0;
    issue_sequence = '0;
    issue_accept = 1'b0;
    clear_gpr_valid = 1'b0;
    clear_pred_valid = 1'b0;
    clear_epoch = '0;
    clear_warp = '0;
    clear_sequence = '0;
    clear_gpr = '0;
    clear_pred = '0;
    checks = 0;
    clear_query();

    if (SIMT_STACK_DEPTH != 8 || SCRATCHPAD_BYTES != 4096 ||
        SHMEM_BYTES != 2048 || MAX_MEMORY_OPS != 4 ||
        COMPLETION_QUEUE_DEPTH != 2 || MULTIPLIER_LATENCY != 3)
      $fatal(1, "unexpected package configuration");

    repeat (2) @(posedge clk);
    @(negedge clk);
    rst = 1'b0;
    #1;
    checks++;
    if (!issue_ready || gpr_pending != '0 || pred_pending != '0)
      $fatal(1, "scoreboard reset state mismatch");

    // Allocate warp 1, R5 with its exact epoch and sequence owner.
    issue_warp = 2'd1;
    issue_epoch = 6'h09;
    issue_sequence = 16'h1001;
    issue_gpr_dest_valid = 1'b1;
    issue_gpr_dest = 4'd5;
    accept_issue();
    clear_query();
    checks++;
    if (!gpr_pending[1][5]) $fatal(1, "GPR destination was not allocated");

    issue_gpr_sources[5] = 1'b1;
    #1;
    checks++;
    if (issue_ready) $fatal(1, "GPR RAW dependency was not blocked");
    clear_query();
    issue_gpr_dest_valid = 1'b1;
    issue_gpr_dest = 4'd5;
    #1;
    checks++;
    if (issue_ready) $fatal(1, "GPR WAW dependency was not blocked");

    issue_warp = 2'd2;
    #1;
    checks++;
    if (!issue_ready) $fatal(1, "dependency leaked between warps");

    // Wrong epoch and wrong sequence must not clear the pending owner.
    clear_query();
    issue_warp = 2'd1;
    clear_gpr_valid = 1'b1;
    clear_warp = 2'd1;
    clear_gpr = 4'd5;
    clear_epoch = 6'h08;
    clear_sequence = 16'h1001;
    @(posedge clk);
    #1;
    checks++;
    if (!gpr_pending[1][5]) $fatal(1, "wrong epoch cleared GPR pending state");
    clear_epoch = 6'h09;
    clear_sequence = 16'h1000;
    @(posedge clk);
    #1;
    checks++;
    if (!gpr_pending[1][5]) $fatal(1, "wrong sequence cleared GPR pending state");

    // Matching GPR commit releases RAW in the commit cycle for RF forwarding.
    @(negedge clk);
    clear_sequence = 16'h1001;
    issue_gpr_sources[5] = 1'b1;
    issue_gpr_dest_valid = 1'b1;
    issue_gpr_dest = 4'd6;
    issue_epoch = 6'h09;
    issue_sequence = 16'h1002;
    #1;
    checks++;
    if (!issue_ready) $fatal(1, "matching GPR commit did not release RAW");
    issue_accept = 1'b1;
    @(posedge clk);
    #1;
    issue_accept = 1'b0;
    clear_gpr_valid = 1'b0;
    clear_query();
    checks++;
    if (gpr_pending[1][5] || !gpr_pending[1][6])
      $fatal(1, "same-cycle GPR clear/allocation mismatch");

    // Allocate P2, then prove readers and writers both wait through commit.
    issue_epoch = 6'h0a;
    issue_sequence = 16'h2001;
    issue_pred_dest_valid = 1'b1;
    issue_pred_dest = 2'd2;
    accept_issue();
    clear_query();
    checks++;
    if (!pred_pending[1][2]) $fatal(1, "predicate destination was not allocated");

    clear_pred_valid = 1'b1;
    clear_warp = 2'd1;
    clear_pred = 2'd2;
    clear_epoch = 6'h0a;
    clear_sequence = 16'h2001;
    issue_pred_sources[2] = 1'b1;
    #1;
    checks++;
    if (issue_ready) $fatal(1, "predicate RAW incorrectly forwarded");
    clear_query();
    issue_pred_dest_valid = 1'b1;
    issue_pred_dest = 2'd2;
    #1;
    checks++;
    if (issue_ready) $fatal(1, "predicate WAW incorrectly bypassed commit");
    @(posedge clk);
    #1;
    clear_pred_valid = 1'b0;
    clear_query();
    checks++;
    if (pred_pending[1][2] || !issue_ready)
      $fatal(1, "predicate did not become available after commit edge");

    // Host clear removes every pending owner across all warps.
    @(negedge clk);
    clear = 1'b1;
    @(posedge clk);
    #1;
    clear = 1'b0;
    checks++;
    if (gpr_pending != '0 || pred_pending != '0)
      $fatal(1, "host clear did not reset scoreboards");

    $display("PASS tb_dependency_scoreboard checks=%0d", checks);
    $finish;
  end
endmodule
