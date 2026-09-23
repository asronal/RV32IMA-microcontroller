// =============================================================================
// File: hazard_unit.sv
// Description: Hazard Detection & Pipeline Stall/Flush Controller
// Features:
//   - Detects load-use data hazards and inserts a 1-cycle bubble into ID/EX
//   - Detects control hazards (taken branches/jumps) and flushes IF/ID & ID/EX
//   - Branch flush strictly takes priority over load-use stalls
//   - Fully combinational and synthesizable for Synopsys DC
// Standard: IEEE 1800-2017 SystemVerilog (Synthesizable for Synopsys DC)
// =============================================================================

`timescale 1ns / 1ps

module hazard_unit (
  // Source register usage and addresses from ID stage
  input  logic [4:0] id_rs1_addr,
  input  logic [4:0] id_rs2_addr,
  input  logic       id_rs1_used,
  input  logic       id_rs2_used,

  // Destination register and memory read flag from EX stage
  input  logic       ex_mem_read,
  input  logic [4:0] ex_rd_addr,

  // Branch / Jump evaluation from EX stage
  input  logic       branch_taken,

  // Pipeline flow controls
  output logic       stall_pc,
  output logic       stall_if_id,
  output logic       flush_if_id,
  output logic       flush_id_ex
);

  // ---------------------------------------------------------------------------
  // Load-Use Hazard Condition
  // An instruction currently in EX is a LOAD, and the instruction currently in
  // ID requires that load's destination register as an input operand.
  // ---------------------------------------------------------------------------
  logic load_use_hazard;

  assign load_use_hazard = ex_mem_read && (ex_rd_addr != 5'd0) &&
                           ((id_rs1_used && (id_rs1_addr == ex_rd_addr)) ||
                            (id_rs2_used && (id_rs2_addr == ex_rd_addr)));

  // ---------------------------------------------------------------------------
  // Pipeline Control Arbitration
  // Priority 1: Taken branch/jump flushes younger instructions in IF/ID & ID/EX
  // Priority 2: Load-use hazard stalls PC & IF/ID and inserts bubble into ID/EX
  // Default: Normal execution
  // ---------------------------------------------------------------------------
  always_comb begin
    if (branch_taken) begin
      // Branch redirection: discard misfetched instructions
      stall_pc    = 1'b0;
      stall_if_id = 1'b0;
      flush_if_id = 1'b1;
      flush_id_ex = 1'b1;
    end else if (load_use_hazard) begin
      // Load-use stall: hold PC & IF/ID, bubble ID/EX
      stall_pc    = 1'b1;
      stall_if_id = 1'b1;
      flush_if_id = 1'b0;
      flush_id_ex = 1'b1;
    end else begin
      // Normal flow
      stall_pc    = 1'b0;
      stall_if_id = 1'b0;
      flush_if_id = 1'b0;
      flush_id_ex = 1'b0;
    end
  end

endmodule : hazard_unit
