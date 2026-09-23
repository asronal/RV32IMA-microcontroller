// =============================================================================
// File: tb_decoder.sv
// Description: Comprehensive self-checking unit testbench for RV32IMA Decoder
// Standard: IEEE 1800-2017 SystemVerilog
// =============================================================================

`timescale 1ns / 1ps

module tb_decoder;
  import rv32_pkg::*;

  logic [31:0]       instr;

  // Outputs from DUT
  logic [4:0]        rs1_addr;
  logic [4:0]        rs2_addr;
  logic [4:0]        rd_addr;
  logic              reg_write;
  logic              mem_read;
  logic              mem_write;
  mem_size_e         mem_size;
  logic              mem_unsigned;
  branch_type_e      branch_type;
  logic              jump;
  logic              jump_is_jalr;
  alu_op_e           alu_op;
  alu_src_a_e        alu_src_a;
  alu_src_b_e        alu_src_b;
  wb_src_e           wb_src;
  imm_src_e          imm_src;
  logic              is_atomic;
  amo_op_e           amo_op;
  logic              is_csr;
  logic              is_mret;
  logic              is_wfi;
  logic              is_ecall;
  logic              is_ebreak;
  logic              illegal_instr;

  int error_count = 0;
  int test_count  = 0;

  // Instantiate DUT
  decoder dut (
    .instr         (instr),
    .rs1_addr      (rs1_addr),
    .rs2_addr      (rs2_addr),
    .rd_addr       (rd_addr),
    .reg_write     (reg_write),
    .mem_read      (mem_read),
    .mem_write     (mem_write),
    .mem_size      (mem_size),
    .mem_unsigned  (mem_unsigned),
    .branch_type   (branch_type),
    .jump          (jump),
    .jump_is_jalr  (jump_is_jalr),
    .alu_op        (alu_op),
    .alu_src_a     (alu_src_a),
    .alu_src_b     (alu_src_b),
    .wb_src        (wb_src),
    .imm_src       (imm_src),
    .is_atomic     (is_atomic),
    .amo_op        (amo_op),
    .is_csr        (is_csr),
    .is_mret       (is_mret),
    .is_wfi        (is_wfi),
    .is_ecall      (is_ecall),
    .is_ebreak     (is_ebreak),
    .illegal_instr (illegal_instr)
  );

  task check_cond(input logic condition, input string test_name);
    #1;
    test_count++;
    if (!condition) begin
      $display("[FAIL] %s: instr=0x%08h decoded incorrectly!", test_name, instr);
      error_count++;
    end else begin
      $display("[PASS] %s (0x%08h)", test_name, instr);
    end
  endtask

  initial begin
    $display("\n========================================================");
    $display("         STARTING TESTBENCH: tb_decoder");
    $display("========================================================");

    // -------------------------------------------------------------------------
    // Test 1: LUI (x5, 0x12345)
    // -------------------------------------------------------------------------
    instr = {20'h12345, 5'd5, 7'b0110111};
    #1;
    check_cond(reg_write && (rd_addr == 5'd5) && (alu_op == ALU_ADD) &&
               (alu_src_a == ALU_SRC_A_ZERO) && (alu_src_b == ALU_SRC_B_IMM) &&
               (wb_src == WB_SRC_ALU) && !illegal_instr,
               "LUI x5, 0x12345");

    // -------------------------------------------------------------------------
    // Test 2: AUIPC (x10, 0x1000)
    // -------------------------------------------------------------------------
    instr = {20'h01000, 5'd10, 7'b0010111};
    #1;
    check_cond(reg_write && (rd_addr == 5'd10) && (alu_src_a == ALU_SRC_A_PC) &&
               (alu_src_b == ALU_SRC_B_IMM) && (wb_src == WB_SRC_ALU) && !illegal_instr,
               "AUIPC x10, 0x1000");

    // -------------------------------------------------------------------------
    // Test 3: JAL (x1, +8)
    // -------------------------------------------------------------------------
    instr = {1'b0, 10'd0, 1'b0, 8'd0, 5'd1, 7'b1101111};
    #1;
    check_cond(reg_write && (rd_addr == 5'd1) && jump && !jump_is_jalr &&
               (wb_src == WB_SRC_PC4) && !illegal_instr,
               "JAL x1, +8");

    // -------------------------------------------------------------------------
    // Test 4: JALR (x1, x2, 4)
    // -------------------------------------------------------------------------
    instr = {12'd4, 5'd2, 3'b000, 5'd1, 7'b1100111};
    #1;
    check_cond(reg_write && (rd_addr == 5'd1) && (rs1_addr == 5'd2) && jump &&
               jump_is_jalr && (wb_src == WB_SRC_PC4) && !illegal_instr,
               "JALR x1, 4(x2)");

    // -------------------------------------------------------------------------
    // Test 5: BEQ (x1, x2, offset)
    // -------------------------------------------------------------------------
    instr = {7'b0000000, 5'd2, 5'd1, 3'b000, 5'b00000, 7'b1100011};
    #1;
    check_cond((branch_type == BRANCH_BEQ) && (rs1_addr == 5'd1) &&
               (rs2_addr == 5'd2) && !reg_write && !illegal_instr,
               "BEQ x1, x2");

    // -------------------------------------------------------------------------
    // Test 6: BNE, BLT, BGE, BLTU, BGEU
    // -------------------------------------------------------------------------
    instr = {7'b0, 5'd2, 5'd1, 3'b001, 5'b0, 7'b1100011}; #1; check_cond(branch_type == BRANCH_BNE, "BNE");
    instr = {7'b0, 5'd2, 5'd1, 3'b100, 5'b0, 7'b1100011}; #1; check_cond(branch_type == BRANCH_BLT, "BLT");
    instr = {7'b0, 5'd2, 5'd1, 3'b101, 5'b0, 7'b1100011}; #1; check_cond(branch_type == BRANCH_BGE, "BGE");
    instr = {7'b0, 5'd2, 5'd1, 3'b110, 5'b0, 7'b1100011}; #1; check_cond(branch_type == BRANCH_BLTU, "BLTU");
    instr = {7'b0, 5'd2, 5'd1, 3'b111, 5'b0, 7'b1100011}; #1; check_cond(branch_type == BRANCH_BGEU, "BGEU");

    // -------------------------------------------------------------------------
    // Test 7: Loads (LB, LH, LW, LBU, LHU)
    // -------------------------------------------------------------------------
    instr = {12'd0, 5'd3, 3'b000, 5'd4, 7'b0000011}; #1; check_cond(mem_read && reg_write && (mem_size == MEM_SIZE_BYTE) && !mem_unsigned, "LB");
    instr = {12'd0, 5'd3, 3'b001, 5'd4, 7'b0000011}; #1; check_cond(mem_read && reg_write && (mem_size == MEM_SIZE_HALF) && !mem_unsigned, "LH");
    instr = {12'd0, 5'd3, 3'b010, 5'd4, 7'b0000011}; #1; check_cond(mem_read && reg_write && (mem_size == MEM_SIZE_WORD) && !mem_unsigned, "LW");
    instr = {12'd0, 5'd3, 3'b100, 5'd4, 7'b0000011}; #1; check_cond(mem_read && reg_write && (mem_size == MEM_SIZE_BYTE) && mem_unsigned, "LBU");
    instr = {12'd0, 5'd3, 3'b101, 5'd4, 7'b0000011}; #1; check_cond(mem_read && reg_write && (mem_size == MEM_SIZE_HALF) && mem_unsigned, "LHU");

    // -------------------------------------------------------------------------
    // Test 8: Stores (SB, SH, SW)
    // -------------------------------------------------------------------------
    instr = {7'b0, 5'd5, 5'd6, 3'b000, 5'b0, 7'b0100011}; #1; check_cond(mem_write && !reg_write && (mem_size == MEM_SIZE_BYTE), "SB");
    instr = {7'b0, 5'd5, 5'd6, 3'b001, 5'b0, 7'b0100011}; #1; check_cond(mem_write && !reg_write && (mem_size == MEM_SIZE_HALF), "SH");
    instr = {7'b0, 5'd5, 5'd6, 3'b010, 5'b0, 7'b0100011}; #1; check_cond(mem_write && !reg_write && (mem_size == MEM_SIZE_WORD), "SW");

    // -------------------------------------------------------------------------
    // Test 9: OP_IMM (ADDI, SLTI, SLTIU, XORI, ORI, ANDI, SLLI, SRLI, SRAI)
    // -------------------------------------------------------------------------
    instr = {12'd10, 5'd1, 3'b000, 5'd2, 7'b0010011}; #1; check_cond(reg_write && (alu_op == ALU_ADD), "ADDI");
    instr = {12'd10, 5'd1, 3'b010, 5'd2, 7'b0010011}; #1; check_cond(reg_write && (alu_op == ALU_SLT), "SLTI");
    instr = {12'd10, 5'd1, 3'b011, 5'd2, 7'b0010011}; #1; check_cond(reg_write && (alu_op == ALU_SLTU), "SLTIU");
    instr = {12'd10, 5'd1, 3'b100, 5'd2, 7'b0010011}; #1; check_cond(reg_write && (alu_op == ALU_XOR), "XORI");
    instr = {12'd10, 5'd1, 3'b110, 5'd2, 7'b0010011}; #1; check_cond(reg_write && (alu_op == ALU_OR), "ORI");
    instr = {12'd10, 5'd1, 3'b111, 5'd2, 7'b0010011}; #1; check_cond(reg_write && (alu_op == ALU_AND), "ANDI");
    instr = {7'b0000000, 5'd4, 5'd1, 3'b001, 5'd2, 7'b0010011}; #1; check_cond(reg_write && (alu_op == ALU_SLL), "SLLI");
    instr = {7'b0000000, 5'd4, 5'd1, 3'b101, 5'd2, 7'b0010011}; #1; check_cond(reg_write && (alu_op == ALU_SRL), "SRLI");
    instr = {7'b0100000, 5'd4, 5'd1, 3'b101, 5'd2, 7'b0010011}; #1; check_cond(reg_write && (alu_op == ALU_SRA), "SRAI");

    // -------------------------------------------------------------------------
    // Test 10: OP (ADD, SUB, SLL, SLT, SLTU, XOR, SRL, SRA, OR, AND)
    // -------------------------------------------------------------------------
    instr = {7'b0000000, 5'd2, 5'd1, 3'b000, 5'd3, 7'b0110011}; #1; check_cond(reg_write && (alu_op == ALU_ADD), "ADD");
    instr = {7'b0100000, 5'd2, 5'd1, 3'b000, 5'd3, 7'b0110011}; #1; check_cond(reg_write && (alu_op == ALU_SUB), "SUB");
    instr = {7'b0000000, 5'd2, 5'd1, 3'b001, 5'd3, 7'b0110011}; #1; check_cond(reg_write && (alu_op == ALU_SLL), "SLL");
    instr = {7'b0000000, 5'd2, 5'd1, 3'b010, 5'd3, 7'b0110011}; #1; check_cond(reg_write && (alu_op == ALU_SLT), "SLT");
    instr = {7'b0000000, 5'd2, 5'd1, 3'b011, 5'd3, 7'b0110011}; #1; check_cond(reg_write && (alu_op == ALU_SLTU), "SLTU");
    instr = {7'b0000000, 5'd2, 5'd1, 3'b100, 5'd3, 7'b0110011}; #1; check_cond(reg_write && (alu_op == ALU_XOR), "XOR");
    instr = {7'b0000000, 5'd2, 5'd1, 3'b101, 5'd3, 7'b0110011}; #1; check_cond(reg_write && (alu_op == ALU_SRL), "SRL");
    instr = {7'b0100000, 5'd2, 5'd1, 3'b101, 5'd3, 7'b0110011}; #1; check_cond(reg_write && (alu_op == ALU_SRA), "SRA");
    instr = {7'b0000000, 5'd2, 5'd1, 3'b110, 5'd3, 7'b0110011}; #1; check_cond(reg_write && (alu_op == ALU_OR), "OR");
    instr = {7'b0000000, 5'd2, 5'd1, 3'b111, 5'd3, 7'b0110011}; #1; check_cond(reg_write && (alu_op == ALU_AND), "AND");

    // -------------------------------------------------------------------------
    // Test 11: RV32A Atomics (LR.W, SC.W, AMOADD.W, AMOSWAP.W)
    // -------------------------------------------------------------------------
    // LR.W (funct5 = 00010, aq=0, rl=0, rs2=0)
    instr = {5'b00010, 2'b00, 5'd0, 5'd1, 3'b010, 5'd3, 7'b0101111};
    #1;
    check_cond(is_atomic && (amo_op == AMO_OP_LR) && reg_write && !illegal_instr, "LR.W");

    // SC.W (funct5 = 00011, aq=0, rl=0)
    instr = {5'b00011, 2'b00, 5'd2, 5'd1, 3'b010, 5'd3, 7'b0101111};
    #1;
    check_cond(is_atomic && (amo_op == AMO_OP_SC) && reg_write && !illegal_instr, "SC.W");

    // AMOADD.W (funct5 = 00000)
    instr = {5'b00000, 2'b00, 5'd2, 5'd1, 3'b010, 5'd3, 7'b0101111};
    #1;
    check_cond(is_atomic && (amo_op == AMO_OP_ADD) && reg_write && !illegal_instr, "AMOADD.W");

    // AMOSWAP.W (funct5 = 00001)
    instr = {5'b00001, 2'b00, 5'd2, 5'd1, 3'b010, 5'd3, 7'b0101111};
    #1;
    check_cond(is_atomic && (amo_op == AMO_OP_SWAP) && reg_write && !illegal_instr, "AMOSWAP.W");

    // -------------------------------------------------------------------------
    // Test 12: SYSTEM / Privileged instructions
    // -------------------------------------------------------------------------
    instr = {12'h302, 5'd0, 3'b000, 5'd0, 7'b1110011}; #1; check_cond(is_mret && !illegal_instr, "MRET");
    instr = {12'h105, 5'd0, 3'b000, 5'd0, 7'b1110011}; #1; check_cond(is_wfi && !illegal_instr, "WFI");
    instr = {12'h000, 5'd0, 3'b000, 5'd0, 7'b1110011}; #1; check_cond(is_ecall && !illegal_instr, "ECALL");
    instr = {12'h001, 5'd0, 3'b000, 5'd0, 7'b1110011}; #1; check_cond(is_ebreak && !illegal_instr, "EBREAK");

    // -------------------------------------------------------------------------
    // Test 13: Illegal Instruction Trapping
    // -------------------------------------------------------------------------
    instr = 32'hFFFF_FFFF; #1; check_cond(illegal_instr, "ILLEGAL_ALL_ONES");
    instr = 32'h0000_0000; #1; check_cond(illegal_instr, "ILLEGAL_ALL_ZEROES");
    // Invalid funct7 on OP
    instr = {7'b1111111, 5'd2, 5'd1, 3'b000, 5'd3, 7'b0110011}; #1; check_cond(illegal_instr, "ILLEGAL_OP_FUNCT7");

    // -------------------------------------------------------------------------
    // Summary
    // -------------------------------------------------------------------------
    $display("========================================================");
    if (error_count == 0) begin
      $display(" >>> ALL %0d TESTS PASSED SUCCESSFULLY! <<<", test_count);
    end else begin
      $display(" >>> FAILED: %0d / %0d TESTS FAILED! <<<", error_count, test_count);
    end
    $display("========================================================\n");
    $finish;
  end

endmodule : tb_decoder
