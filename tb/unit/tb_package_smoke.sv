module tb_package_smoke;
  import simt_gpu_pkg::*;
  initial begin
    if (LANES != 8 || WARPS != 4 || XLEN != 32 || SIMT_STACK_DEPTH != 8 ||
        SCRATCHPAD_BYTES != 4096 || SHMEM_BYTES != 2048 ||
        MAX_MEMORY_OPS != 4 || COMPLETION_QUEUE_DEPTH != 2 ||
        KERNEL_EPOCH_WIDTH != 6 || INSTRUCTION_SEQUENCE_WIDTH != 16 ||
        MULTIPLIER_LATENCY != 3)
      $fatal(1, "baseline package parameter mismatch");
    $display("PASS tb_package_smoke");
    $finish;
  end
endmodule
