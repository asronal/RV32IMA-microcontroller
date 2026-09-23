// =============================================================================
// File: immediate_gen.sv
// Description: RV32 Immediate Generator
// Supports: I-type, S-type, B-type, U-type, J-type, and CSR immediate (Zicsr)
// Standard: IEEE 1800-2017 SystemVerilog (Synthesizable for Synopsys DC)
// =============================================================================

`timescale 1ns / 1ps

module immediate_gen
  import rv32_pkg::*;
(
  input  logic [31:0]   instr,
  input  imm_src_e      imm_src,
  output logic [31:0]   imm_out
);

  // ---------------------------------------------------------------------------
  // Purely Combinational Immediate Extraction
  // Every case explicitly defines the full 32-bit width with sign extension.
  // Default assignment prevents any latch inference.
  // ---------------------------------------------------------------------------
  always_comb begin
    imm_out = 32'd0;

    case (imm_src)
      // I-type: 12-bit signed immediate (ALU imm, Loads, JALR)
      IMM_SRC_I: begin
        imm_out = {{20{instr[31]}}, instr[31:20]};
      end

      // S-type: 12-bit signed immediate (Stores)
      IMM_SRC_S: begin
        imm_out = {{20{instr[31]}}, instr[31:25], instr[11:7]};
      end

      // B-type: 13-bit signed branch target offset (Branches, multiple of 2)
      IMM_SRC_B: begin
        imm_out = {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0};
      end

      // U-type: 20-bit upper immediate shifted by 12 (LUI, AUIPC)
      IMM_SRC_U: begin
        imm_out = {instr[31:12], 12'b0};
      end

      // J-type: 21-bit signed jump target offset (JAL, multiple of 2)
      IMM_SRC_J: begin
        imm_out = {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0};
      end

      // CSR immediate: 5-bit unsigned zero-extended (CSRRWI, CSRRSI, CSRRCI)
      IMM_SRC_CSR: begin
        imm_out = {27'd0, instr[19:15]};
      end

      default: begin
        imm_out = 32'd0;
      end
    endcase
  end

endmodule : immediate_gen
