// =============================================================================
// File: regfile.sv
// Description: RV32I 32x32-bit General Purpose Register File
// Features:
//   - Dual asynchronous read ports (combinational read)
//   - Single synchronous write port (posedge clk)
//   - Register x0 is hardwired to 32'h0000_0000 (writes to x0 are discarded)
//   - Asynchronous active-low reset initializes registers x1..x31 to zero
// Standard: IEEE 1800-2017 SystemVerilog (Synthesizable for Synopsys DC)
// =============================================================================

`timescale 1ns / 1ps

module regfile (
  input  logic        clk,
  input  logic        rst_n,

  // Read Port 1 (Asynchronous)
  input  logic [4:0]  rs1_addr,
  output logic [31:0] rs1_data,

  // Read Port 2 (Asynchronous)
  input  logic [4:0]  rs2_addr,
  output logic [31:0] rs2_data,

  // Write Port (Synchronous)
  input  logic        we,
  input  logic [4:0]  waddr,
  input  logic [31:0] wdata
);

  // ---------------------------------------------------------------------------
  // Register Storage
  // Indices 1 to 31 are physical registers.
  // x0 is permanently zero and requires no physical flip-flops.
  // ---------------------------------------------------------------------------
  logic [31:0] rf [1:31];

  // ---------------------------------------------------------------------------
  // Asynchronous Read Ports
  // If address is zero, hardwire to 32'h0000_0000.
  // ---------------------------------------------------------------------------
  assign rs1_data = (rs1_addr == 5'd0) ? 32'd0 : rf[rs1_addr];
  assign rs2_data = (rs2_addr == 5'd0) ? 32'd0 : rf[rs2_addr];

  // ---------------------------------------------------------------------------
  // Synchronous Write Port with Reset
  // Writes to x0 (waddr == 5'd0) are explicitly ignored.
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      for (int i = 1; i < 32; i = i + 1) begin
        rf[i] <= 32'd0;
      end
    end else begin
      if (we && (waddr != 5'd0)) begin
        rf[waddr] <= wdata;
      end
    end
  end

endmodule : regfile
