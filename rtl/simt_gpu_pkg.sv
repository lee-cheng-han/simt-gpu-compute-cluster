package simt_gpu_pkg;
  parameter int unsigned LANES = 8;
  parameter int unsigned WARPS = 4;
  parameter int unsigned REGS_PER_THREAD = 16;
  parameter int unsigned PREDS_PER_THREAD = 4;
  parameter int unsigned XLEN = 32;
  parameter int unsigned SIMT_STACK_DEPTH = 8;
  parameter int unsigned SHMEM_BYTES = 8192;
  typedef logic [LANES-1:0] lane_mask_t;
  typedef logic [XLEN-1:0] word_t;
endpackage

