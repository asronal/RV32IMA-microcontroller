// =============================================================================
// File: alu.sv
// Description: Purely combinational 32-bit ALU supporting RV32I base integer ops
// Operations: ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU, COPY_B
// Standard: IEEE 1800-2017 SystemVerilog (Synthesizable for Synopsys DC)
// =============================================================================

`timescale 1ns / 1ps

module alu
  import rv32_pkg::*;
(
  input  logic [31:0]   op_a,
  input  logic [31:0]   op_b,
  input  alu_op_e       alu_op,
  output logic [31:0]   result,
  output logic          zero
);

  // ---------------------------------------------------------------------------
  // Internal Shift Amount (Shift operations only use lowest 5 bits)
  // ---------------------------------------------------------------------------
  logic [4:0] shamt;
  assign shamt = op_b[4:0];

  // ---------------------------------------------------------------------------
  // Combinational ALU Core
  // Unconditional default assignments ensure zero latch inference.
  // Explicit signed/unsigned casts guarantee deterministic synthesis.
  // ---------------------------------------------------------------------------
  always_comb begin
    result = 32'd0;

    case (alu_op)
      ALU_ADD: begin
        result = op_a + op_b;
      end

      ALU_SUB: begin
        result = op_a - op_b;
      end

      ALU_AND: begin
        result = op_a & op_b;
      end

      ALU_OR: begin
        result = op_a | op_b;
      end

      ALU_XOR: begin
        result = op_a ^ op_b;
      end

      ALU_SLL: begin
        result = op_a << shamt;
      end

      ALU_SRL: begin
        result = op_a >> shamt;
      end

      ALU_SRA: begin
        result = $signed(op_a) >>> shamt;
      end

      ALU_SLT: begin
        result = ($signed(op_a) < $signed(op_b)) ? 32'd1 : 32'd0;
      end

      ALU_SLTU: begin
        result = (op_a < op_b) ? 32'd1 : 32'd0;
      end

      ALU_COPY_B: begin
        result = op_b;
      end

      default: begin
        result = 32'd0;
      end
    endcase
  end

  // Zero status flag
  assign zero = (result == 32'd0);

endmodule : alu
