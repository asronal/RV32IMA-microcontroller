// =============================================================================
// File: if_id.sv
// Description: IF/ID Pipeline Stage Register
// Features:
//   - Registers Instruction Fetch stage outputs (PC, PC+4, raw instruction)
//   - Supports synchronous flush (bubble insertion: NOP / invalid)
//   - Supports synchronous stall (clock enable hold for load-use hazards)
//   - Active-low asynchronous reset
// Standard: IEEE 1800-2017 SystemVerilog (Synthesizable for Synopsys DC)
// =============================================================================

`timescale 1ns / 1ps

module if_id (
  input  logic        clk,
  input  logic        rst_n,

  // Pipeline Flow Control
  input  logic        stall,
  input  logic        flush,

  // Inputs from IF Stage
  input  logic [31:0] if_pc,
  input  logic [31:0] if_pc4,
  input  logic [31:0] if_instr,
  input  logic        if_valid,

  // Outputs to ID Stage
  output logic [31:0] id_pc,
  output logic [31:0] id_pc4,
  output logic [31:0] id_instr,
  output logic        id_valid
);

  // Canonical NOP: addi x0, x0, 0 (0x00000013)
  localparam logic [31:0] NOP_INSTR = 32'h0000_0013;

  // ---------------------------------------------------------------------------
  // Sequential Pipeline Register
  // Priority:
  //   1. Reset (rst_n == 0)
  //   2. Flush (flush == 1) -> Insert bubble (NOP, valid=0)
  //   3. Stall (stall == 1) -> Hold previous values
  //   4. Normal capture (!stall)
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      id_pc    <= 32'd0;
      id_pc4   <= 32'd0;
      id_instr <= NOP_INSTR;
      id_valid <= 1'b0;
    end else if (flush) begin
      id_pc    <= 32'd0;
      id_pc4   <= 32'd0;
      id_instr <= NOP_INSTR;
      id_valid <= 1'b0;
    end else if (!stall) begin
      id_pc    <= if_pc;
      id_pc4   <= if_pc4;
      id_instr <= if_instr;
      id_valid <= if_valid;
    end
  end

endmodule : if_id
