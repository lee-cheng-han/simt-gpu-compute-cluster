module tb_completion_queue;
  import simt_gpu_pkg::*;

  logic clk = 1'b0;
  logic rst;
  logic flush;
  logic input_valid;
  logic input_ready;
  completion_record_t input_record;
  logic output_valid;
  logic output_ready;
  completion_record_t output_record;
  logic [1:0] occupancy;
  int unsigned checks;

  always #5 clk <= ~clk;

  completion_queue dut (
    .clk(clk),
    .rst(rst),
    .flush_i(flush),
    .completion_valid_i(input_valid),
    .completion_ready_o(input_ready),
    .completion_i(input_record),
    .completion_valid_o(output_valid),
    .completion_ready_i(output_ready),
    .completion_o(output_record),
    .occupancy_o(occupancy)
  );

  function automatic completion_record_t make_record(
    input logic [INSTRUCTION_SEQUENCE_WIDTH-1:0] instruction_sequence,
    input completion_class_t completion_class
  );
    completion_record_t result;
    result = '0;
    result.valid = 1'b1;
    result.epoch = instruction_sequence[KERNEL_EPOCH_WIDTH-1:0];
    result.warp_id = instruction_sequence[WARP_ID_WIDTH-1:0];
    result.sequence_number = instruction_sequence;
    result.pc = 32'h1000_0000 | word_t'(instruction_sequence);
    result.instruction = 32'h8000_0000 | word_t'(instruction_sequence);
    result.active_mask = 8'ha5 ^ instruction_sequence[7:0];
    result.write_mask = 8'h5a ^ instruction_sequence[7:0];
    result.writes_gpr = instruction_sequence[0];
    result.gpr_dst = instruction_sequence[REG_INDEX_WIDTH-1:0];
    result.gpr_mask = 8'hc3 ^ instruction_sequence[7:0];
    for (int unsigned lane = 0; lane < LANES; lane++)
      result.gpr_data[lane] = 32'h4000_0000 |
                              (word_t'(instruction_sequence) << 8) |
                              word_t'(lane);
    result.writes_pred = !instruction_sequence[0];
    result.pred_dst = instruction_sequence[PRED_INDEX_WIDTH-1:0];
    result.pred_mask = 8'h3c ^ instruction_sequence[7:0];
    result.pred_data = 8'h69 ^ instruction_sequence[7:0];
    result.clear_gpr_pending = instruction_sequence[0];
    result.clear_pred_pending = !instruction_sequence[0];
    result.completion_class = completion_class;
    result.status = COMPLETION_STATUS_OK;
    return result;
  endfunction

  task automatic push(input completion_record_t record);
    @(negedge clk);
    if (!input_ready) $fatal(1, "queue not ready for push");
    input_record = record;
    input_valid = 1'b1;
    @(posedge clk);
    #1;
    input_valid = 1'b0;
  endtask

  task automatic pop_and_check(input completion_record_t expected);
    @(negedge clk);
    if (!output_valid) $fatal(1, "queue empty before pop");
    if (output_record !== expected) $fatal(1, "completion payload mismatch");
    output_ready = 1'b1;
    @(posedge clk);
    #1;
    output_ready = 1'b0;
    checks++;
  endtask

  initial begin
    completion_record_t record_a;
    completion_record_t record_b;
    completion_record_t record_c;
    completion_record_t record_d;
    completion_record_t held_record;

    rst = 1'b1;
    flush = 1'b0;
    input_valid = 1'b0;
    output_ready = 1'b0;
    input_record = '0;
    checks = 0;
    record_a = make_record(16'h0011, COMPLETION_ALU);
    record_b = make_record(16'h0022, COMPLETION_MULTIPLIER);
    record_c = make_record(16'h0033, COMPLETION_MEMORY);
    record_d = make_record(16'h0044, COMPLETION_ALU);

    if (SIMT_STACK_DEPTH != 8 || SCRATCHPAD_BYTES != 4096 ||
        SHMEM_BYTES != 2048 || MAX_MEMORY_OPS != 4 ||
        MULTIPLIER_LATENCY != 3)
      $fatal(1, "unexpected package configuration");

    repeat (2) @(posedge clk);
    @(negedge clk);
    rst = 1'b0;
    #1;
    checks++;
    if (output_valid || occupancy != 0 || !input_ready)
      $fatal(1, "reset state mismatch");

    push(record_a);
    checks++;
    if (!output_valid || occupancy != 1 || output_record !== record_a)
      $fatal(1, "first enqueue mismatch");

    push(record_b);
    checks++;
    if (!output_valid || occupancy != 2 || input_ready ||
        output_record !== record_a)
      $fatal(1, "full queue mismatch");

    held_record = output_record;
    repeat (3) begin
      @(posedge clk);
      #1;
      checks++;
      if (!output_valid || output_record !== held_record || occupancy != 2)
        $fatal(1, "stalled queue changed");
    end

    pop_and_check(record_a);
    checks++;
    if (!output_valid || occupancy != 1 || output_record !== record_b)
      $fatal(1, "FIFO order mismatch after first pop");

    // Drain and refill on the same edge while wrapping both ring pointers.
    @(negedge clk);
    output_ready = 1'b1;
    input_valid = 1'b1;
    input_record = record_c;
    if (!input_ready || output_record !== record_b)
      $fatal(1, "simultaneous drain/refill was not accepted");
    @(posedge clk);
    #1;
    output_ready = 1'b0;
    input_valid = 1'b0;
    checks++;
    if (!output_valid || occupancy != 1 || output_record !== record_c)
      $fatal(1, "simultaneous drain/refill mismatch");

    push(record_d);
    pop_and_check(record_c);
    pop_and_check(record_d);
    checks++;
    if (output_valid || occupancy != 0 || !input_ready)
      $fatal(1, "queue did not drain");

    push(record_a);
    push(record_b);
    @(negedge clk);
    flush = 1'b1;
    output_ready = 1'b1;
    @(posedge clk);
    #1;
    flush = 1'b0;
    output_ready = 1'b0;
    checks++;
    if (output_valid || occupancy != 0 || !input_ready)
      $fatal(1, "flush did not cancel queued records");

    $display("PASS tb_completion_queue checks=%0d", checks);
    $finish;
  end
endmodule
