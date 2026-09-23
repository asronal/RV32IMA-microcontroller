// =============================================================================
// File: atomic_unit.sv
// Description: RV32A Atomic Memory Operations (AMO) and LR/SC Controller
// Features:
//   - Implements LR.W (Load-Reserved Word) and SC.W (Store-Conditional Word)
//   - Single-core reservation tracking: reservation_valid, reservation_address
//   - Invalidates reservation on intervening stores to the reserved address
//   - Implements AMOADD.W, AMOSWAP.W
//   - Complete logic for AMOXOR, AMOAND, AMOOR, AMOMIN, AMOMAX, AMOMINU, AMOMAXU
// Standard: IEEE 1800-2017 SystemVerilog (Synthesizable for Synopsys DC)
// =============================================================================

`timescale 1ns / 1ps

module atomic_unit
  import rv32_pkg::*;
(
  input  logic        clk,
  input  logic        rst_n,

  // Atomic operation request from MEM stage
  input  logic        is_atomic,
  input  amo_op_e     amo_op,
  input  logic [31:0] mem_addr,
  input  logic [31:0] mem_rdata,
  input  logic [31:0] rs2_data,

  // External / Standard store invalidation monitoring
  input  logic        store_valid,
  input  logic [31:0] store_addr,

  // Outputs to Memory Bus and Writeback
  output logic [31:0] amo_wdata,
  output logic [31:0] amo_rdata,
  output logic        amo_mem_write,
  output logic        sc_success,

  // Reservation Status
  output logic        res_valid,
  output logic [31:0] res_addr
);

  // ---------------------------------------------------------------------------
  // Reservation Register State
  // ---------------------------------------------------------------------------
  logic        res_valid_q;
  logic [31:0] res_addr_q;

  assign res_valid = res_valid_q;
  assign res_addr  = res_addr_q;

  // SC.W Success Condition:
  // Must have a valid reservation matching the target address.
  assign sc_success = res_valid_q && (res_addr_q == mem_addr);

  // ---------------------------------------------------------------------------
  // Reservation State Management
  // ---------------------------------------------------------------------------
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      res_valid_q <= 1'b0;
      res_addr_q  <= 32'd0;
    end else begin
      if (is_atomic && (amo_op == AMO_OP_LR)) begin
        // LR.W creates a new reservation
        res_valid_q <= 1'b1;
        res_addr_q  <= mem_addr;
      end else if (is_atomic && (amo_op == AMO_OP_SC)) begin
        // SC.W unconditionally clears the reservation
        res_valid_q <= 1'b0;
      end else if (store_valid && res_valid_q && (store_addr == res_addr_q)) begin
        // Intervening standard store to the same address clears the reservation
        res_valid_q <= 1'b0;
      end
    end
  end

  // ---------------------------------------------------------------------------
  // AMO Arithmetic and Writeback Evaluation
  // Unconditional default assignments eliminate latch inference.
  // ---------------------------------------------------------------------------
  always_comb begin
    amo_wdata     = 32'd0;
    amo_rdata     = 32'd0;
    amo_mem_write = 1'b0;

    if (is_atomic) begin
      case (amo_op)
        // ---------------------------------------------------------------------
        // LR.W: Load-Reserved Word
        // Returns memory word to rd; does not write to memory.
        // ---------------------------------------------------------------------
        AMO_OP_LR: begin
          amo_rdata     = mem_rdata;
          amo_wdata     = 32'd0;
          amo_mem_write = 1'b0;
        end

        // ---------------------------------------------------------------------
        // SC.W: Store-Conditional Word
        // Writes rs2 to memory if reservation valid.
        // Returns 0 in rd on success, 1 on failure.
        // ---------------------------------------------------------------------
        AMO_OP_SC: begin
          amo_rdata     = sc_success ? 32'd0 : 32'd1;
          amo_wdata     = rs2_data;
          amo_mem_write = sc_success;
        end

        // ---------------------------------------------------------------------
        // AMOSWAP.W: Atomic Swap Word
        // Returns original memory word, writes rs2 to memory.
        // ---------------------------------------------------------------------
        AMO_OP_SWAP: begin
          amo_rdata     = mem_rdata;
          amo_wdata     = rs2_data;
          amo_mem_write = 1'b1;
        end

        // ---------------------------------------------------------------------
        // AMOADD.W: Atomic Add Word
        // Returns original memory word, writes (mem + rs2) to memory.
        // ---------------------------------------------------------------------
        AMO_OP_ADD: begin
          amo_rdata     = mem_rdata;
          amo_wdata     = mem_rdata + rs2_data;
          amo_mem_write = 1'b1;
        end

        // ---------------------------------------------------------------------
        // AMOXOR.W: Atomic XOR Word
        // ---------------------------------------------------------------------
        AMO_OP_XOR: begin
          amo_rdata     = mem_rdata;
          amo_wdata     = mem_rdata ^ rs2_data;
          amo_mem_write = 1'b1;
        end

        // ---------------------------------------------------------------------
        // AMOAND.W: Atomic AND Word
        // ---------------------------------------------------------------------
        AMO_OP_AND: begin
          amo_rdata     = mem_rdata;
          amo_wdata     = mem_rdata & rs2_data;
          amo_mem_write = 1'b1;
        end

        // ---------------------------------------------------------------------
        // AMOOR.W: Atomic OR Word
        // ---------------------------------------------------------------------
        AMO_OP_OR: begin
          amo_rdata     = mem_rdata;
          amo_wdata     = mem_rdata | rs2_data;
          amo_mem_write = 1'b1;
        end

        // ---------------------------------------------------------------------
        // AMOMIN.W: Atomic Minimum (Signed)
        // ---------------------------------------------------------------------
        AMO_OP_MIN: begin
          amo_rdata     = mem_rdata;
          amo_wdata     = ($signed(mem_rdata) < $signed(rs2_data)) ? mem_rdata : rs2_data;
          amo_mem_write = 1'b1;
        end

        // ---------------------------------------------------------------------
        // AMOMAX.W: Atomic Maximum (Signed)
        // ---------------------------------------------------------------------
        AMO_OP_MAX: begin
          amo_rdata     = mem_rdata;
          amo_wdata     = ($signed(mem_rdata) > $signed(rs2_data)) ? mem_rdata : rs2_data;
          amo_mem_write = 1'b1;
        end

        // ---------------------------------------------------------------------
        // AMOMINU.W: Atomic Minimum (Unsigned)
        // ---------------------------------------------------------------------
        AMO_OP_MINU: begin
          amo_rdata     = mem_rdata;
          amo_wdata     = (mem_rdata < rs2_data) ? mem_rdata : rs2_data;
          amo_mem_write = 1'b1;
        end

        // ---------------------------------------------------------------------
        // AMOMAXU.W: Atomic Maximum (Unsigned)
        // ---------------------------------------------------------------------
        AMO_OP_MAXU: begin
          amo_rdata     = mem_rdata;
          amo_wdata     = (mem_rdata > rs2_data) ? mem_rdata : rs2_data;
          amo_mem_write = 1'b1;
        end

        default: begin
          amo_rdata     = mem_rdata;
          amo_wdata     = 32'd0;
          amo_mem_write = 1'b0;
        end
      endcase
    end
  end

endmodule : atomic_unit
