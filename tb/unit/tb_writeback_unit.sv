module tb_writeback_unit;
  localparam int unsigned LANES = 8;
  logic clk = 0, rst, flush;
  logic result_valid, result_ready, result_writes_gpr, result_writes_pred;
  logic [1:0] result_warp, result_pred;
  logic [3:0] result_rd;
  logic [31:0] result_pc;
  logic [LANES-1:0] result_gpr_mask, result_pred_mask, result_predicate;
  logic [LANES-1:0][31:0] result_data;
  logic commit_valid, commit_ready;
  logic [1:0] commit_warp, gpr_warp, pred_warp, pred_index;
  logic [31:0] commit_pc;
  logic gpr_valid, pred_valid;
  logic [3:0] gpr_reg;
  logic [LANES-1:0] gpr_mask, pred_mask, pred_data;
  logic [LANES-1:0][31:0] gpr_data;
  int unsigned checks;

  always #5 clk <= ~clk;

  writeback_unit dut (
    .clk(clk), .rst(rst), .flush_i(flush),
    .result_valid_i(result_valid), .result_ready_o(result_ready),
    .result_warp_i(result_warp), .result_pc_i(result_pc),
    .result_rd_i(result_rd), .result_pred_i(result_pred),
    .result_writes_gpr_i(result_writes_gpr),
    .result_writes_pred_i(result_writes_pred),
    .result_gpr_mask_i(result_gpr_mask), .result_pred_mask_i(result_pred_mask),
    .result_data_i(result_data), .result_predicate_i(result_predicate),
    .commit_valid_o(commit_valid), .commit_ready_i(commit_ready),
    .commit_warp_o(commit_warp), .commit_pc_o(commit_pc),
    .gpr_write_valid_o(gpr_valid), .gpr_write_warp_o(gpr_warp),
    .gpr_write_reg_o(gpr_reg), .gpr_write_mask_o(gpr_mask),
    .gpr_write_data_o(gpr_data), .pred_write_valid_o(pred_valid),
    .pred_write_warp_o(pred_warp), .pred_write_pred_o(pred_index),
    .pred_write_mask_o(pred_mask), .pred_write_data_o(pred_data)
  );

  task automatic drive_payload(
    input logic [1:0] warp,
    input logic [31:0] pc,
    input logic [3:0] rd,
    input logic [1:0] pred,
    input logic writes_gpr,
    input logic writes_pred,
    input logic [7:0] gm,
    input logic [7:0] pm,
    input logic [7:0] pdata,
    input logic [31:0] salt
  );
    result_warp = warp;
    result_pc = pc;
    result_rd = rd;
    result_pred = pred;
    result_writes_gpr = writes_gpr;
    result_writes_pred = writes_pred;
    result_gpr_mask = gm;
    result_pred_mask = pm;
    result_predicate = pdata;
    for (int unsigned lane = 0; lane < LANES; lane++)
      result_data[lane] = salt | lane;
  endtask

  task automatic enqueue;
    @(negedge clk);
    if (!result_ready) $fatal(1, "writeback input not ready");
    result_valid = 1;
    @(posedge clk);
    #1;
    result_valid = 0;
  endtask

  initial begin
    rst = 1;
    flush = 0;
    result_valid = 0;
    commit_ready = 0;
    drive_payload(0, 0, 0, 0, 0, 0, 0, 0, 0, 0);
    checks = 0;
    repeat (2) @(posedge clk);
    @(negedge clk);
    rst = 0;

    drive_payload(2, 32'h40, 9, 0, 1, 0, 8'b1010_0110, 0, 0, 32'h9000_0000);
    enqueue();
    checks++;
    if (!commit_valid || commit_warp != 2 || commit_pc != 32'h40 ||
        gpr_valid || pred_valid || result_ready)
      $fatal(1, "buffered GPR result state mismatch");

    // Backpressure must preserve the entire buffered transaction.
    repeat (3) begin
      @(posedge clk);
      #1;
      checks++;
      if (!commit_valid || commit_warp != 2 || commit_pc != 32'h40 ||
          gpr_mask != 8'b1010_0110 || gpr_reg != 9 || gpr_valid || pred_valid)
        $fatal(1, "writeback payload changed while stalled");
      for (int unsigned lane = 0; lane < LANES; lane++) begin
        if (gpr_data[lane] != (32'h9000_0000 | lane))
          $fatal(1, "writeback data changed while stalled lane=%0d", lane);
      end
    end

    // A ready commit generates exactly the selected architectural write.
    @(negedge clk);
    commit_ready = 1;
    #1;
    checks++;
    if (!gpr_valid || pred_valid || gpr_warp != 2 || gpr_reg != 9 ||
        gpr_mask != 8'b1010_0110)
      $fatal(1, "GPR commit mismatch");
    @(posedge clk);
    #1;
    commit_ready = 0;
    checks++;
    if (commit_valid || gpr_valid || pred_valid) $fatal(1, "commit did not drain");

    drive_payload(1, 32'h88, 0, 3, 0, 1, 0, 8'b0101_1001,
                  8'b0011_1100, 32'ha000_0000);
    enqueue();
    @(negedge clk);
    commit_ready = 1;
    #1;
    checks++;
    if (gpr_valid || !pred_valid || pred_warp != 1 || pred_index != 3 ||
        pred_mask != 8'b0101_1001 || pred_data != 8'b0011_1100)
      $fatal(1, "predicate commit mismatch");

    // Consume the predicate result and replace it with a GPR result in one edge.
    drive_payload(3, 32'h100, 4, 0, 1, 0, 8'hff, 0, 0, 32'hb000_0000);
    result_valid = 1;
    @(posedge clk);
    #1;
    result_valid = 0;
    commit_ready = 0;
    checks++;
    if (!commit_valid || commit_warp != 3 || commit_pc != 32'h100 ||
        gpr_mask != 8'hff)
      $fatal(1, "simultaneous drain/refill mismatch");
    for (int unsigned lane = 0; lane < LANES; lane++) begin
      if (gpr_data[lane] != (32'hb000_0000 | lane))
        $fatal(1, "replacement data mismatch lane=%0d", lane);
    end

    // Flush cancels a buffered result without an architectural write.
    @(negedge clk);
    flush = 1;
    @(posedge clk);
    #1;
    flush = 0;
    checks++;
    if (commit_valid || gpr_valid || pred_valid) $fatal(1, "flush did not cancel writeback");

    // Empty masks never create writes even when the instruction completes.
    drive_payload(0, 32'h200, 1, 2, 1, 1, 0, 0, 8'hff, 32'hc000_0000);
    enqueue();
    @(negedge clk);
    commit_ready = 1;
    #1;
    checks++;
    if (!commit_valid || gpr_valid || pred_valid)
      $fatal(1, "empty masks created architectural writes");
    @(posedge clk);
    #1;

    $display("PASS tb_writeback_unit checks=%0d", checks);
    $finish;
  end
endmodule
