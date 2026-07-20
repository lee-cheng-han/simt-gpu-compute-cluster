module tb_instruction_fetch;
  localparam int unsigned WORDS = 16;
  logic clk = 1'b0;
  logic rst, clear_fault, start_valid, start_ready, halt, redirect_valid;
  logic [31:0] start_pc, redirect_pc;
  logic imem_fetch_valid;
  logic [3:0] imem_fetch_addr;
  logic [31:0] imem_fetch_data;
  logic fetch_valid, fetch_ready, running, fault_valid;
  logic [31:0] fetch_pc, fetch_instr, fault_pc;
  logic prog_valid;
  logic [3:0] prog_addr;
  logic [31:0] prog_data;
  int unsigned checks;

  always #5 clk <= ~clk;

  instruction_memory #(.WORDS(WORDS)) memory_u (
    .clk(clk), .prog_valid_i(prog_valid), .prog_addr_i(prog_addr),
    .prog_data_i(prog_data), .fetch_valid_i(imem_fetch_valid),
    .fetch_addr_i(imem_fetch_addr), .fetch_data_o(imem_fetch_data)
  );

  instruction_fetch #(.IMEM_WORDS(WORDS)) fetch_u (
    .clk(clk), .rst(rst), .clear_fault_i(clear_fault),
    .start_valid_i(start_valid), .start_ready_o(start_ready), .start_pc_i(start_pc),
    .halt_i(halt), .redirect_valid_i(redirect_valid), .redirect_pc_i(redirect_pc),
    .imem_fetch_valid_o(imem_fetch_valid), .imem_fetch_addr_o(imem_fetch_addr),
    .imem_fetch_data_i(imem_fetch_data), .fetch_valid_o(fetch_valid),
    .fetch_ready_i(fetch_ready), .fetch_pc_o(fetch_pc), .fetch_instr_o(fetch_instr),
    .running_o(running), .fault_valid_o(fault_valid), .fault_pc_o(fault_pc)
  );

  task automatic program_word(input logic [3:0] address, input logic [31:0] data);
    @(negedge clk);
    prog_valid = 1'b1;
    prog_addr = address;
    prog_data = data;
    @(posedge clk);
    #1;
    prog_valid = 1'b0;
  endtask

  task automatic launch(input logic [31:0] pc);
    @(negedge clk);
    if (!start_ready) $fatal(1, "fetch was not ready to start");
    start_valid = 1'b1;
    start_pc = pc;
    @(posedge clk);
    #1;
    start_valid = 1'b0;
  endtask

  task automatic expect_fetch(input logic [31:0] pc);
    while (!fetch_valid) @(negedge clk);
    #1;
    checks++;
    if (fetch_pc !== pc || fetch_instr !== (32'ha500_0000 | pc))
      $fatal(1, "fetch mismatch pc=%0d got_pc=%0d instr=%08x", pc, fetch_pc, fetch_instr);
    @(posedge clk);
    #1;
  endtask

  initial begin
    rst = 1;
    clear_fault = 0;
    start_valid = 0;
    start_pc = 0;
    halt = 0;
    redirect_valid = 0;
    redirect_pc = 0;
    fetch_ready = 1;
    prog_valid = 0;
    prog_addr = 0;
    prog_data = 0;
    checks = 0;
    repeat (2) @(posedge clk);
    @(negedge clk);
    rst = 0;

    for (int unsigned address = 0; address < WORDS; address++)
      program_word(4'(address), 32'ha500_0000 | address);

    launch(3);
    expect_fetch(3);
    expect_fetch(4);

    // Hold a response for three cycles and require exact stability.
    fetch_ready = 0;
    while (!fetch_valid) @(posedge clk);
    #1;
    for (int unsigned cycle = 0; cycle < 3; cycle++) begin
      logic [31:0] held_pc, held_instr;
      held_pc = fetch_pc;
      held_instr = fetch_instr;
      @(posedge clk);
      #1;
      checks++;
      if (!fetch_valid || fetch_pc != held_pc || fetch_instr != held_instr)
        $fatal(1, "fetch changed while stalled");
    end
    fetch_ready = 1;
    @(posedge clk);
    #1;

    // Redirect discards any buffered sequential instruction.
    @(negedge clk);
    redirect_valid = 1;
    redirect_pc = 10;
    @(posedge clk);
    #1;
    redirect_valid = 0;
    expect_fetch(10);

    // Fetching the final word then accepting it faults on the next PC.
    @(negedge clk);
    redirect_valid = 1;
    redirect_pc = 15;
    @(posedge clk);
    #1;
    redirect_valid = 0;
    expect_fetch(15);
    @(posedge clk);
    #1;
    checks++;
    if (!fault_valid || fault_pc != 16 || running || fetch_valid)
      $fatal(1, "sequential range fault mismatch");
    repeat (2) begin
      @(posedge clk);
      #1;
      checks++;
      if (!fault_valid || fault_pc != 16 || start_ready)
        $fatal(1, "range fault was not sticky");
    end

    @(negedge clk);
    clear_fault = 1;
    @(posedge clk);
    #1;
    clear_fault = 0;
    checks++;
    if (fault_valid || !start_ready) $fatal(1, "fault clear failed");

    // An invalid launch faults without issuing an instruction-memory request.
    launch(20);
    checks++;
    if (!fault_valid || fault_pc != 20 || running || imem_fetch_valid)
      $fatal(1, "invalid start fault mismatch");

    @(negedge clk);
    clear_fault = 1;
    @(posedge clk);
    #1;
    clear_fault = 0;
    launch(1);
    expect_fetch(1);
    @(negedge clk);
    halt = 1;
    @(posedge clk);
    #1;
    halt = 0;
    checks++;
    if (running || fetch_valid || imem_fetch_valid)
      $fatal(1, "halt did not stop fetch");

    $display("PASS tb_instruction_fetch checks=%0d", checks);
    $finish;
  end
endmodule
