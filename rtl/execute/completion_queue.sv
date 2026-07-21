module completion_queue (
  input  logic                              clk,
  input  logic                              rst,
  input  logic                              flush_i,

  input  logic                              completion_valid_i,
  output logic                              completion_ready_o,
  input  simt_gpu_pkg::completion_record_t  completion_i,

  output logic                              completion_valid_o,
  input  logic                              completion_ready_i,
  output simt_gpu_pkg::completion_record_t  completion_o,
  output logic [1:0]                        occupancy_o
);
  import simt_gpu_pkg::*;

  completion_record_t entries_q [0:COMPLETION_QUEUE_DEPTH-1];
  localparam logic [1:0] QUEUE_DEPTH = 2'd2;
  logic head_q;
  logic tail_q;
  logic [1:0] occupancy_q;
  logic enqueue;
  logic dequeue;

  always_comb begin
    completion_valid_o = (occupancy_q != 0);
    completion_o = entries_q[head_q];
    occupancy_o = occupancy_q;

    dequeue = completion_valid_o && completion_ready_i;
    completion_ready_o = (occupancy_q < QUEUE_DEPTH) || dequeue;
    enqueue = completion_valid_i && completion_ready_o;
  end

  always_ff @(posedge clk) begin
    if (rst || flush_i) begin
      entries_q[0] <= '0;
      entries_q[1] <= '0;
      head_q <= 1'b0;
      tail_q <= 1'b0;
      occupancy_q <= '0;
    end else begin
      if (enqueue) begin
        entries_q[tail_q] <= completion_i;
        tail_q <= tail_q + 1'b1;
      end

      if (dequeue)
        head_q <= head_q + 1'b1;

      case ({enqueue, dequeue})
        2'b10: occupancy_q <= occupancy_q + 1'b1;
        2'b01: occupancy_q <= occupancy_q - 1'b1;
        default: occupancy_q <= occupancy_q;
      endcase
    end
  end

`ifndef SYNTHESIS
  property p_output_stable_while_stalled;
    @(posedge clk) disable iff (rst || flush_i)
      completion_valid_o && !completion_ready_i
      |=> completion_valid_o && $stable(completion_o);
  endproperty
  assert property (p_output_stable_while_stalled)
    else $error("completion queue payload changed while stalled");

  property p_occupancy_in_range;
    @(posedge clk) disable iff (rst)
      occupancy_q <= QUEUE_DEPTH;
  endproperty
  assert property (p_occupancy_in_range)
    else $error("completion queue occupancy exceeded depth");

  property p_enqueued_record_is_valid;
    @(posedge clk) disable iff (rst || flush_i)
      enqueue |-> completion_i.valid;
  endproperty
  assert property (p_enqueued_record_is_valid)
    else $error("completion queue accepted a record without its valid tag");

  property p_output_record_is_valid;
    @(posedge clk) disable iff (rst || flush_i)
      completion_valid_o |-> completion_o.valid;
  endproperty
  assert property (p_output_record_is_valid)
    else $error("completion queue exposed a record without its valid tag");
`endif
endmodule
