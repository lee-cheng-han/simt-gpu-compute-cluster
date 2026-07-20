module predicate_register_file #(
  parameter int unsigned LANES = 8,
  parameter int unsigned WARPS = 4,
  parameter int unsigned PREDS = 4,
  parameter int unsigned WARP_W = $clog2(WARPS),
  parameter int unsigned PRED_W = $clog2(PREDS)
) (
  input  logic clk,
  input  logic rst,

  input  logic              read_valid_i,
  input  logic [WARP_W-1:0] read_warp_i,
  input  logic [PRED_W-1:0] read_pred_i,
  output logic [LANES-1:0]  read_mask_o,

  input  logic              write_valid_i,
  input  logic [WARP_W-1:0] write_warp_i,
  input  logic [PRED_W-1:0] write_pred_i,
  input  logic [LANES-1:0]  write_lane_mask_i,
  input  logic [LANES-1:0]  write_data_i
);
  logic [LANES-1:0] predicates [WARPS][PREDS];

  always_comb begin
    read_mask_o = '0;
    if (read_valid_i && !rst) begin
      read_mask_o = predicates[read_warp_i][read_pred_i];
      if (write_valid_i && write_warp_i == read_warp_i &&
          write_pred_i == read_pred_i) begin
        for (int unsigned lane = 0; lane < LANES; lane++) begin
          if (write_lane_mask_i[lane])
            read_mask_o[lane] = write_data_i[lane];
        end
      end
    end
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      for (int unsigned warp = 0; warp < WARPS; warp++) begin
        for (int unsigned pred = 0; pred < PREDS; pred++) begin
          predicates[warp][pred] <= '0;
        end
      end
    end else if (write_valid_i) begin
      for (int unsigned lane = 0; lane < LANES; lane++) begin
        if (write_lane_mask_i[lane])
          predicates[write_warp_i][write_pred_i][lane] <= write_data_i[lane];
      end
    end
  end

`ifndef SYNTHESIS
  for (genvar lane = 0; lane < LANES; lane++) begin : gen_write_assertions
    property p_masked_lane_write;
      @(posedge clk) disable iff (rst)
        (write_valid_i && write_lane_mask_i[lane])
        |=> (predicates[$past(write_warp_i)][$past(write_pred_i)][lane] ==
             $past(write_data_i[lane]));
    endproperty
    assert property (p_masked_lane_write)
      else $error("predicate write mismatch on lane %0d", lane);

    property p_unmasked_lane_preserved;
      @(posedge clk) disable iff (rst)
        (write_valid_i && !write_lane_mask_i[lane])
        |=> (predicates[$past(write_warp_i)][$past(write_pred_i)][lane] ==
             $past(predicates[write_warp_i][write_pred_i][lane]));
    endproperty
    assert property (p_unmasked_lane_preserved)
      else $error("unmasked predicate lane changed on lane %0d", lane);
  end
`endif
endmodule
