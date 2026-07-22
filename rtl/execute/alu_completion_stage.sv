module alu_completion_stage (
  input  logic                                            clk,
  input  logic                                            rst,
  input  logic                                            flush_i,

  input  logic                                            result_valid_i,
  output logic                                            result_ready_o,
  input  logic [simt_gpu_pkg::KERNEL_EPOCH_WIDTH-1:0]     epoch_i,
  input  logic [simt_gpu_pkg::WARP_ID_WIDTH-1:0]          warp_id_i,
  input  logic [simt_gpu_pkg::INSTRUCTION_SEQUENCE_WIDTH-1:0]
                                                            sequence_number_i,
  input  logic [31:0]                                     pc_i,
  input  logic [31:0]                                     instruction_i,
  input  simt_gpu_pkg::lane_mask_t                        active_mask_i,
  input  simt_gpu_pkg::lane_mask_t                        write_mask_i,
  input  logic                                            writes_gpr_i,
  input  logic [simt_gpu_pkg::REG_INDEX_WIDTH-1:0]        gpr_dst_i,
  input  simt_gpu_pkg::lane_mask_t                        gpr_mask_i,
  input  simt_gpu_pkg::word_t [simt_gpu_pkg::LANES-1:0]  gpr_data_i,
  input  logic                                            writes_pred_i,
  input  logic [simt_gpu_pkg::PRED_INDEX_WIDTH-1:0]       pred_dst_i,
  input  simt_gpu_pkg::lane_mask_t                        pred_mask_i,
  input  simt_gpu_pkg::lane_mask_t                        pred_data_i,

  output logic                                            completion_valid_o,
  input  logic                                            completion_ready_i,
  output simt_gpu_pkg::completion_record_t                completion_o,
  output logic [1:0]                                      occupancy_o
);
  import simt_gpu_pkg::*;

  completion_record_t assembled_completion;

  always_comb begin
    assembled_completion = '0;
    assembled_completion.valid = result_valid_i;
    assembled_completion.epoch = epoch_i;
    assembled_completion.warp_id = warp_id_i;
    assembled_completion.sequence_number = sequence_number_i;
    assembled_completion.pc = pc_i;
    assembled_completion.instruction = instruction_i;
    assembled_completion.active_mask = active_mask_i;
    assembled_completion.write_mask = write_mask_i;
    assembled_completion.writes_gpr = writes_gpr_i;
    assembled_completion.gpr_dst = gpr_dst_i;
    assembled_completion.gpr_mask = gpr_mask_i;
    assembled_completion.gpr_data = gpr_data_i;
    assembled_completion.writes_pred = writes_pred_i;
    assembled_completion.pred_dst = pred_dst_i;
    assembled_completion.pred_mask = pred_mask_i;
    assembled_completion.pred_data = pred_data_i;
    assembled_completion.clear_gpr_pending = writes_gpr_i;
    assembled_completion.clear_pred_pending = writes_pred_i;
    assembled_completion.completion_class = COMPLETION_ALU;
    assembled_completion.status = COMPLETION_STATUS_OK;
  end

  completion_queue queue_u (
    .clk(clk),
    .rst(rst),
    .flush_i(flush_i),
    .completion_valid_i(result_valid_i),
    .completion_ready_o(result_ready_o),
    .completion_i(assembled_completion),
    .completion_valid_o(completion_valid_o),
    .completion_ready_i(completion_ready_i),
    .completion_o(completion_o),
    .occupancy_o(occupancy_o)
  );
endmodule
