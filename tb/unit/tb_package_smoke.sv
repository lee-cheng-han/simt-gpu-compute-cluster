module tb_package_smoke;
  import simt_gpu_pkg::*;
  initial begin
    if (LANES != 8 || WARPS != 4 || XLEN != 32 || SIMT_STACK_DEPTH != 8)
      $fatal(1, "baseline package parameter mismatch");
    $display("PASS tb_package_smoke");
    $finish;
  end
endmodule
