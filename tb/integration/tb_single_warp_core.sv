module tb_single_warp_core;
  import simt_gpu_pkg::*;
  logic clk = 0, rst, clear, prog_valid, launch_valid;
  logic [5:0] prog_addr; logic [31:0] prog_data, launch_pc, fault_pc;
  logic launch_ready, running, done, fault, commit_valid;
  completion_record_t commit;
  int unsigned commits;
  always #5 clk <= ~clk;
  single_warp_core dut (.*,
    .clear_i(clear), .prog_valid_i(prog_valid), .prog_addr_i(prog_addr),
    .prog_data_i(prog_data), .launch_valid_i(launch_valid),
    .launch_ready_o(launch_ready), .launch_pc_i(launch_pc),
    .running_o(running), .done_o(done), .fault_o(fault),
    .fault_pc_o(fault_pc), .commit_valid_o(commit_valid), .commit_o(commit));

  task automatic program_word(input logic [5:0] address, input logic [31:0] data);
    @(negedge clk); prog_addr = address; prog_data = data; prog_valid = 1;
    @(posedge clk); #1; prog_valid = 0;
  endtask
  initial begin
    rst=1; clear=0; prog_valid=0; prog_addr=0; prog_data=0;
    launch_valid=0; launch_pc=0; commits=0;
    repeat(2) @(posedge clk); @(negedge clk); rst=0;
    program_word(0,32'h38040007); program_word(1,32'h38080003);
    program_word(2,32'h040c4800); program_word(3,32'h4000cc00);
    program_word(4,32'h0610c400); program_word(5,32'h78000000);
    @(negedge clk); if(!launch_ready) $fatal(1,"launch not ready");
    launch_valid=1; @(posedge clk); #1; launch_valid=0;
    repeat (80) begin
      @(negedge clk); #1;
      if (fault) $fatal(1,"core fault pc=%0d",fault_pc);
      if (commit_valid) begin
        if ($isunknown(commit)) $fatal(1,"unknown bit in completion record");
        if (commit.sequence_number != INSTRUCTION_SEQUENCE_WIDTH'(commits))
          $fatal(1,"commit sequence mismatch got=%0d expected=%0d",
                 commit.sequence_number, commits);
        case (commits)
          0: if (!commit.writes_gpr || commit.gpr_dst != 1 ||
                 commit.gpr_data[0] != 7) $fatal(1,"MOVI R1 mismatch");
          1: if (!commit.writes_gpr || commit.gpr_dst != 2 ||
                 commit.gpr_data[7] != 3) $fatal(1,"MOVI R2 mismatch");
          2: if (!commit.writes_gpr || commit.gpr_dst != 3 ||
                 commit.gpr_data[3] != 10) $fatal(1,"dependent ADD mismatch");
          3: if (!commit.writes_pred || commit.pred_dst != 0 ||
                 commit.pred_data != 8'hff) $fatal(1,"SETP mismatch");
          4: if (!commit.writes_gpr || commit.gpr_dst != 4 ||
                 commit.gpr_data[5] != 17) $fatal(1,"predicated ADD mismatch");
          5: if (commit.writes_gpr || commit.writes_pred ||
                 commit.active_mask != 8'hff) $fatal(1,"EXIT mismatch");
          default: $fatal(1,"unexpected extra commit");
        endcase
        commits++;
      end
      if (done) begin
        if (commits != 6 || running) $fatal(1,"completion state mismatch");
        $display("PASS tb_single_warp_core commits=%0d", commits);
        $finish;
      end
    end
    $fatal(1,"single-warp program timed out commits=%0d", commits);
  end
endmodule
