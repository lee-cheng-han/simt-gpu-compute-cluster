module tb_predicate_register_file;
  localparam int unsigned LANES = 8;
  localparam int unsigned WARPS = 4;
  localparam int unsigned PREDS = 4;

  logic clk = 1'b0;
  logic rst;
  logic read_valid;
  logic [1:0] read_warp, read_pred;
  logic [LANES-1:0] read_mask;
  logic write_valid;
  logic [1:0] write_warp, write_pred;
  logic [LANES-1:0] write_lane_mask, write_data;
  logic [LANES-1:0] expected [WARPS][PREDS];
  int unsigned checks;

  always #5 clk <= ~clk;

  predicate_register_file dut (
    .clk(clk), .rst(rst),
    .read_valid_i(read_valid), .read_warp_i(read_warp),
    .read_pred_i(read_pred), .read_mask_o(read_mask),
    .write_valid_i(write_valid), .write_warp_i(write_warp),
    .write_pred_i(write_pred), .write_lane_mask_i(write_lane_mask),
    .write_data_i(write_data)
  );

  function automatic logic [LANES-1:0] pattern(
    input int unsigned warp,
    input int unsigned pred,
    input int unsigned salt
  );
    return 8'((32'h0000_0039 << warp) ^ (32'h0000_00a5 >> pred) ^ salt);
  endfunction

  task automatic drive_write(
    input int unsigned warp,
    input int unsigned pred,
    input logic [LANES-1:0] lane_mask,
    input logic [LANES-1:0] data
  );
    if (warp >= WARPS || pred >= PREDS) $fatal(1, "write address out of range");
    @(negedge clk);
    write_valid = 1'b1;
    write_warp = 2'(warp);
    write_pred = 2'(pred);
    write_lane_mask = lane_mask;
    write_data = data;
    for (int unsigned lane = 0; lane < LANES; lane++) begin
      if (lane_mask[lane]) expected[warp][pred][lane] = data[lane];
    end
    @(posedge clk);
    #1;
    write_valid = 1'b0;
    write_lane_mask = '0;
  endtask

  task automatic check_read(input int unsigned warp, input int unsigned pred);
    if (warp >= WARPS || pred >= PREDS) $fatal(1, "read address out of range");
    @(negedge clk);
    read_valid = 1'b1;
    read_warp = 2'(warp);
    read_pred = 2'(pred);
    #1;
    checks++;
    if (read_mask !== expected[warp][pred])
      $fatal(1, "predicate mismatch warp=%0d pred=%0d", warp, pred);
  endtask

  initial begin
    rst = 1'b1;
    read_valid = 1'b0;
    read_warp = '0;
    read_pred = '0;
    write_valid = 1'b0;
    write_warp = '0;
    write_pred = '0;
    write_lane_mask = '0;
    write_data = '0;
    checks = 0;
    for (int unsigned warp = 0; warp < WARPS; warp++)
      for (int unsigned pred = 0; pred < PREDS; pred++)
        expected[warp][pred] = '0;

    repeat (2) @(posedge clk);
    @(negedge clk);
    rst = 1'b0;

    // Reset state and every warp/predicate address.
    for (int unsigned warp = 0; warp < WARPS; warp++)
      for (int unsigned pred = 0; pred < PREDS; pred++)
        check_read(warp, pred);

    for (int unsigned warp = 0; warp < WARPS; warp++) begin
      for (int unsigned pred = 0; pred < PREDS; pred++) begin
        drive_write(warp, pred, '1, pattern(warp, pred, 1));
      end
    end
    for (int unsigned warp = 0; warp < WARPS; warp++)
      for (int unsigned pred = 0; pred < PREDS; pred++)
        check_read(warp, pred);

    // Complementary masks verify both update and preservation behavior.
    drive_write(1, 2, 8'b0101_1010, 8'b1111_0000);
    check_read(1, 2);
    drive_write(1, 2, 8'b1010_0101, 8'b0011_1100);
    check_read(1, 2);

    // Predicate results are not forwarded: consumers see committed state until
    // the write edge, and dependency tracking prevents an architectural read.
    @(negedge clk);
    read_valid = 1'b1;
    read_warp = 2'd2;
    read_pred = 2'd3;
    write_valid = 1'b1;
    write_warp = 2'd2;
    write_pred = 2'd3;
    write_lane_mask = 8'b1100_0011;
    write_data = 8'b1010_0101;
    #1;
    for (int unsigned lane = 0; lane < LANES; lane++) begin
      if (read_mask[lane] !== expected[2][3][lane])
        $fatal(1, "predicate read exposed uncommitted data lane=%0d", lane);
      if (write_lane_mask[lane])
        expected[2][3][lane] = write_data[lane];
      checks++;
    end
    @(posedge clk);
    #1;
    write_valid = 1'b0;
    write_lane_mask = '0;
    check_read(2, 3);

    // Concurrent writes to any warp or predicate remain invisible before commit.
    @(negedge clk);
    read_valid = 1'b1;
    read_warp = 2'd0;
    read_pred = 2'd1;
    write_valid = 1'b1;
    write_warp = 2'd3;
    write_pred = 2'd1;
    write_lane_mask = '1;
    write_data = '1;
    #1;
    if (read_mask !== expected[0][1]) $fatal(1, "cross-warp write affected read");
    checks++;
    write_warp = 2'd0;
    write_pred = 2'd2;
    #1;
    if (read_mask !== expected[0][1]) $fatal(1, "other predicate write affected read");
    checks++;
    write_valid = 1'b0;

    read_valid = 1'b0;
    #1;
    if (read_mask !== '0) $fatal(1, "invalid predicate read was not zero");
    checks++;

    // Reset recovery clears all predicate state.
    @(negedge clk);
    rst = 1'b1;
    @(posedge clk);
    #1;
    rst = 1'b0;
    for (int unsigned warp = 0; warp < WARPS; warp++) begin
      for (int unsigned pred = 0; pred < PREDS; pred++) begin
        expected[warp][pred] = '0;
        check_read(warp, pred);
      end
    end

    $display("PASS tb_predicate_register_file checks=%0d", checks);
    $finish;
  end
endmodule
