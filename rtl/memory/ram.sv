// =============================================================================
// File: ram.sv
// Description: Parameterized Byte-Addressable Synchronous SRAM (Generic RTL)
// Features:
//   - Parameterized capacity (Default: 32 KB = 8192 words)
//   - 4-bit byte-enable write strobes (wstrb[3:0])
//   - Synchronous write, zero-wait read
//   - Synthesizable for FPGA and standard ASIC flows
// Standard: IEEE 1800-2017 SystemVerilog (Synthesizable for Synopsys DC)
// =============================================================================

`timescale 1ns / 1ps

module ram #(
  parameter int RAM_BYTES = 32768
)(
  input  logic        clk,

  // Bus Interface
  input  logic        en,
  input  logic        we,
  input  logic [31:0] addr,
  input  logic [31:0] wdata,
  input  logic [3:0]  wstrb,
  output logic [31:0] rdata
);

  localparam int RAM_WORDS = RAM_BYTES / 4;
  localparam int ADDR_BITS = $clog2(RAM_WORDS);

  // 32-bit word-addressed RAM array
  logic [31:0] mem [0:RAM_WORDS-1];

  // Address word indexing
  logic [ADDR_BITS-1:0] word_idx;
  assign word_idx = addr[ADDR_BITS+1:2];

  // ---------------------------------------------------------------------------
  // Synchronous Byte-Masked Write
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk) begin
    if (en && we) begin
      if (wstrb[0]) mem[word_idx][7:0]   <= wdata[7:0];
      if (wstrb[1]) mem[word_idx][15:8]  <= wdata[15:8];
      if (wstrb[2]) mem[word_idx][23:16] <= wdata[23:16];
      if (wstrb[3]) mem[word_idx][31:24] <= wdata[31:24];
    end
  end

  // ---------------------------------------------------------------------------
  // Read Data Output
  // ---------------------------------------------------------------------------
  assign rdata = en ? mem[word_idx] : 32'd0;

endmodule : ram
