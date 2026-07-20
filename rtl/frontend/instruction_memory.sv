module instruction_memory #(
  parameter int unsigned WORDS = 1024,
  parameter int unsigned ADDR_W = $clog2(WORDS)
) (
  input  logic clk,
  input  logic prog_valid_i,
  input  logic [ADDR_W-1:0] prog_addr_i,
  input  logic [31:0] prog_data_i,
  input  logic fetch_valid_i,
  input  logic [ADDR_W-1:0] fetch_addr_i,
  output logic [31:0] fetch_data_o
);
  logic [31:0] storage [WORDS];

  // The baseline wrapper provides a combinational architectural read. A later
  // backend may insert a registered SRAM/BRAM adapter without changing fetch's
  // valid/ready contract.
  always_comb begin
    fetch_data_o = 32'd0;
    if (fetch_valid_i)
      fetch_data_o = storage[fetch_addr_i];
  end

  always_ff @(posedge clk) begin
    if (prog_valid_i)
      storage[prog_addr_i] <= prog_data_i;
  end

`ifndef SYNTHESIS
  always_ff @(posedge clk) begin
    assert (!(prog_valid_i && fetch_valid_i && prog_addr_i == fetch_addr_i))
      else $error("instruction memory programming/fetch collision");
  end
`endif
endmodule
