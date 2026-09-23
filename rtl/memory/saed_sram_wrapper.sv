// =============================================================================
// File: saed_sram_wrapper.sv
// Description: SAED PDK SRAM Macro Abstraction Wrapper (Phase 13)
//
// Purpose:
//   Provides a clean, pin-abstracted interface between the generic memory bus
//   and the vendor SAED SRAM hard macro. The CPU core, bus decoder, and memory
//   wrapper NEVER reference PDK-specific pin names directly.
//
// Integration Guide:
//   Step 1: Identify your SAED SRAM macro name from the PDK memory compiler.
//           Example macro names:
//             SAED14_SRAM_SP_8192X32_M4       (SAED 14nm, 32 KB single-port)
//             SAED32_SRAM_SP_8192X32           (SAED 32nm, 32 KB single-port)
//
//   Step 2: Check your macro's pin interface from the Liberty (.lib) or LEF file.
//           Common SAED SRAM pin naming conventions:
//
//             Pin      | Direction | Description
//             ---------+-----------+----------------------------------
//             CLK      | Input     | Synchronous clock
//             CEN      | Input     | Chip Enable (Active Low)
//             WEN      | Input     | Write Enable (Active Low)
//             BWEN[N]  | Input     | Bit-Write Enable (Active Low, per bit)
//             A[N]     | Input     | Word Address
//             D[31:0]  | Input     | Write Data
//             Q[31:0]  | Output    | Read Data
//             OEN      | Input     | Output Enable (Active Low, if present)
//
//   Step 3: Replace the behavioral stub below with the actual macro
//           instantiation using the exact pin names from your PDK.
//
//   Step 4: Compile with: +define+USE_SAED_MEMORY
//           The memory_wrapper.sv will then instantiate this wrapper
//           instead of the generic behavioral ram.sv.
//
//   Step 5: For synthesis, ensure the SRAM macro .db is added to
//           link_library in syn/dc.tcl.
//
// Note on Write Byte Enables:
//   The generic bus interface uses 4-bit byte strobes (wstrb[3:0]).
//   SAED macros typically use per-bit write enables (BWEN[31:0]).
//   The mapping is: BWEN[7:0] = {8{~wstrb[0]}}, BWEN[15:8] = {8{~wstrb[1]}}, etc.
//   This is implemented in the byte-to-bit expansion logic below.
//
// Standard: IEEE 1800-2017 SystemVerilog (Synthesizable for Synopsys DC)
// =============================================================================

`timescale 1ns / 1ps

module saed_sram_wrapper #(
  parameter int RAM_BYTES = 32768
)(
  input  logic        clk,

  // Generic bus interface (from memory_wrapper.sv)
  input  logic        en,
  input  logic        we,
  input  logic [31:0] addr,
  input  logic [31:0] wdata,
  input  logic [3:0]  wstrb,
  output logic [31:0] rdata
);

  localparam int RAM_WORDS = RAM_BYTES / 4;
  localparam int ADDR_BITS = $clog2(RAM_WORDS);

  // Word-addressed index from byte address
  logic [ADDR_BITS-1:0] word_addr;
  assign word_addr = addr[ADDR_BITS+1:2];

  // ---------------------------------------------------------------------------
  // Byte-to-Bit Write Enable Expansion
  // SAED macros typically use BWEN[31:0] (active-low bit write enables).
  // Expand the 4-bit byte strobe to 32-bit per-bit enable.
  // ---------------------------------------------------------------------------
  logic [31:0] bwen_n;   // Active-low bit write enable (SAED convention)

  assign bwen_n[7:0]   = {8{~wstrb[0]}};
  assign bwen_n[15:8]  = {8{~wstrb[1]}};
  assign bwen_n[23:16] = {8{~wstrb[2]}};
  assign bwen_n[31:24] = {8{~wstrb[3]}};

  // ---------------------------------------------------------------------------
  // Active-Low Control Derivations (SAED convention)
  // ---------------------------------------------------------------------------
  logic cen_n;  // Chip Enable (active-low)
  logic wen_n;  // Write Enable (active-low)

  assign cen_n = ~en;
  assign wen_n = ~we;

  // ===========================================================================
  // SAED SRAM MACRO INSTANTIATION
  //
  // *** REPLACE THIS SECTION WITH YOUR ACTUAL PDK MACRO ***
  //
  // Example for SAED 32nm 8192x32 single-port SRAM:
  //
  //   SAED32_SRAM_SP_8192X32 u_saed_sram (
  //     .CLK    (clk),
  //     .CEN    (cen_n),
  //     .WEN    (wen_n),
  //     .BWEN   (bwen_n),
  //     .A      (word_addr),
  //     .D      (wdata),
  //     .Q      (rdata)
  //   );
  //
  // Example for SAED 14nm 8192x32 single-port SRAM (pin names may differ):
  //
  //   SAED14_SRAM_SP_8192X32_M4 u_saed_sram (
  //     .CLK    (clk),
  //     .CEN    (cen_n),
  //     .WEN    (wen_n),
  //     .BWEN   (bwen_n),
  //     .A      (word_addr),
  //     .D      (wdata),
  //     .Q      (rdata)
  //   );
  //
  // ===========================================================================

  // ---------------------------------------------------------------------------
  // Behavioral Stub — Active until PDK macro is inserted above.
  // Compile WITHOUT +define+USE_SAED_MEMORY for pure RTL simulation.
  // Remove this stub when inserting the real macro above.
  // ---------------------------------------------------------------------------
  logic [31:0] stub_mem [0:RAM_WORDS-1];

  always_ff @(posedge clk) begin
    if (en && we) begin
      if (wstrb[0]) stub_mem[word_addr][7:0]   <= wdata[7:0];
      if (wstrb[1]) stub_mem[word_addr][15:8]  <= wdata[15:8];
      if (wstrb[2]) stub_mem[word_addr][23:16] <= wdata[23:16];
      if (wstrb[3]) stub_mem[word_addr][31:24] <= wdata[31:24];
    end
  end

  assign rdata = en ? stub_mem[word_addr] : 32'd0;

endmodule : saed_sram_wrapper
