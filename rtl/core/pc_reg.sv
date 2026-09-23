// =============================================================================
// File: pc_reg.sv
// Description: Program Counter Register and Next-PC Generation
// Features:
//   - Synchronous PC update on posedge clk with active-low asynchronous reset
//   - Branch/Jump target redirection with flush priority
//   - Stall capability for load-use and atomic pipeline holds
// Standard: IEEE 1800-2017 SystemVerilog (Synthesizable for Synopsys DC)
// =============================================================================

`timescale 1ns / 1ps

module pc_reg #(
  parameter logic [31:0] RESET_VECTOR = 32'h0000_0000
)(
  input  logic        clk,
  input  logic        rst_n,

  // Hazard / Control signals
  input  logic        stall,
  input  logic        branch_taken,
  input  logic [31:0] branch_target,

  // PC Outputs
  output logic [31:0] pc_curr,
  output logic [31:0] pc_plus4
);

  // Sequential PC increment
  assign pc_plus4 = pc_curr + 32'd4;

  // ---------------------------------------------------------------------------
  // PC State Register
  // Priority:
  //   1. Reset (rst_n == 0) -> RESET_VECTOR
  //   2. Branch / Jump redirection (branch_taken == 1) -> branch_target
  //   3. Stall (stall == 1) -> Hold current PC
  //   4. Normal sequential execution -> pc_plus4
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      pc_curr <= RESET_VECTOR;
    end else if (branch_taken) begin
      pc_curr <= branch_target;
    end else if (!stall) begin
      pc_curr <= pc_plus4;
    end
  end

endmodule : pc_reg
