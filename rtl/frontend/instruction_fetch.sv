module instruction_fetch #(
  parameter int unsigned IMEM_WORDS = 1024,
  parameter int unsigned PC_W = 32,
  parameter int unsigned IMEM_ADDR_W = $clog2(IMEM_WORDS)
) (
  input  logic clk,
  input  logic rst,
  input  logic clear_fault_i,

  input  logic start_valid_i,
  output logic start_ready_o,
  input  logic [PC_W-1:0] start_pc_i,
  input  logic halt_i,
  input  logic redirect_valid_i,
  input  logic [PC_W-1:0] redirect_pc_i,

  output logic imem_fetch_valid_o,
  output logic [IMEM_ADDR_W-1:0] imem_fetch_addr_o,
  input  logic [31:0] imem_fetch_data_i,

  output logic fetch_valid_o,
  input  logic fetch_ready_i,
  output logic [PC_W-1:0] fetch_pc_o,
  output logic [31:0] fetch_instr_o,

  output logic running_o,
  output logic fault_valid_o,
  output logic [PC_W-1:0] fault_pc_o
);
  logic [PC_W-1:0] next_pc_q;
  logic can_advance;
  logic next_pc_in_range;

  always_comb begin
    start_ready_o = !running_o && !fault_valid_o;
    can_advance = !fetch_valid_o || fetch_ready_i;
    next_pc_in_range = (next_pc_q < PC_W'(IMEM_WORDS));
    imem_fetch_valid_o = running_o && !halt_i && !redirect_valid_i &&
                         can_advance && next_pc_in_range;
    imem_fetch_addr_o = IMEM_ADDR_W'(next_pc_q);
  end

  always_ff @(posedge clk) begin
    if (rst) begin
      next_pc_q <= '0;
      fetch_valid_o <= 1'b0;
      fetch_pc_o <= '0;
      fetch_instr_o <= '0;
      running_o <= 1'b0;
      fault_valid_o <= 1'b0;
      fault_pc_o <= '0;
    end else begin
      if (clear_fault_i) begin
        fault_valid_o <= 1'b0;
        fault_pc_o <= '0;
      end

      if (halt_i) begin
        running_o <= 1'b0;
        fetch_valid_o <= 1'b0;
      end else if (start_valid_i && start_ready_o) begin
        fetch_valid_o <= 1'b0;
        if (start_pc_i < PC_W'(IMEM_WORDS)) begin
          next_pc_q <= start_pc_i;
          running_o <= 1'b1;
        end else begin
          running_o <= 1'b0;
          fault_valid_o <= 1'b1;
          fault_pc_o <= start_pc_i;
        end
      end else if (running_o && redirect_valid_i) begin
        fetch_valid_o <= 1'b0;
        if (redirect_pc_i < PC_W'(IMEM_WORDS)) begin
          next_pc_q <= redirect_pc_i;
        end else begin
          running_o <= 1'b0;
          fault_valid_o <= 1'b1;
          fault_pc_o <= redirect_pc_i;
        end
      end else if (running_o && can_advance) begin
        if (next_pc_in_range) begin
          fetch_valid_o <= 1'b1;
          fetch_pc_o <= next_pc_q;
          fetch_instr_o <= imem_fetch_data_i;
          next_pc_q <= next_pc_q + PC_W'(1);
        end else begin
          fetch_valid_o <= 1'b0;
          running_o <= 1'b0;
          fault_valid_o <= 1'b1;
          fault_pc_o <= next_pc_q;
        end
      end
    end
  end

`ifndef SYNTHESIS
  property p_fetch_stable_under_backpressure;
    @(posedge clk) disable iff (rst)
      fetch_valid_o && !fetch_ready_i && !halt_i && !redirect_valid_i
      |=> $stable(fetch_valid_o) && $stable(fetch_pc_o) && $stable(fetch_instr_o);
  endproperty
  assert property (p_fetch_stable_under_backpressure)
    else $error("fetch response changed under backpressure");

  property p_fault_sticky;
    @(posedge clk) disable iff (rst)
      fault_valid_o && !clear_fault_i
      |=> clear_fault_i || (fault_valid_o && $stable(fault_pc_o));
  endproperty
  assert property (p_fault_sticky)
    else $error("fetch fault changed without clear/reset");
`endif
endmodule
