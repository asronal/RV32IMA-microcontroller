// =============================================================================
// File: tb_core.sv
// Description: Comprehensive Integration Testbench for RV32I 5-Stage Core
// Tests:
//   1. Base arithmetic & immediate instructions (LUI, ADDI, ADD, SUB)
//   2. RAW Data Forwarding (EX/MEM -> EX, MEM/WB -> EX)
//   3. Hardware Load-Use Hazard Stall (LW -> ADD)
//   4. Store and Load memory operations (SW, LW, SB, LB, LBU)
//   5. Branch resolution and pipeline flush (BEQ taken flushes bubble)
//   6. Jump and Link execution (JAL links return address and redirects PC)
// Standard: IEEE 1800-2017 SystemVerilog
// =============================================================================

`timescale 1ns / 1ps

module tb_core;
  import rv32_pkg::*;

  logic        clk;
  logic        rst_n;

  // Instruction Memory Interface
  logic [31:0] imem_addr;
  logic        imem_req;
  logic [31:0] imem_rdata;

  // Data Memory Interface
  logic        dmem_valid;
  logic        dmem_write;
  logic [31:0] dmem_addr;
  logic [31:0] dmem_wdata;
  logic [3:0]  dmem_wstrb;
  logic [31:0] dmem_rdata;
  logic        dmem_ready;

  int error_count = 0;
  int test_count  = 0;

  // Instantiate DUT
  rv32_core #(
    .RESET_VECTOR(32'h0000_0000)
  ) dut (
    .clk        (clk),
    .rst_n      (rst_n),
    .imem_addr  (imem_addr),
    .imem_req   (imem_req),
    .imem_rdata (imem_rdata),
    .dmem_valid (dmem_valid),
    .dmem_write (dmem_write),
    .dmem_addr  (dmem_addr),
    .dmem_wdata (dmem_wdata),
    .dmem_wstrb (dmem_wstrb),
    .dmem_rdata (dmem_rdata),
    .dmem_ready (dmem_ready)
  );

  // Clock generation (10ns period = 100MHz)
  always #5 clk = ~clk;

  // ---------------------------------------------------------------------------
  // Memory Subsystem Model (64KB combined word-addressed space)
  // ---------------------------------------------------------------------------
  logic [31:0] mem_array [0:16383];

  // Instruction Read (Word aligned)
  assign imem_rdata = (imem_addr[15:2] < 16384) ? mem_array[imem_addr[15:2]] : 32'h0000_0013;

  // Data Read (Word aligned)
  assign dmem_rdata = (dmem_addr[15:2] < 16384) ? mem_array[dmem_addr[15:2]] : 32'd0;
  assign dmem_ready = 1'b1;

  // Synchronous Data Write with Byte Strobes
  always_ff @(posedge clk) begin
    if (dmem_valid && dmem_write && (dmem_addr[15:2] < 16384)) begin
      if (dmem_wstrb[0]) mem_array[dmem_addr[15:2]][7:0]   <= dmem_wdata[7:0];
      if (dmem_wstrb[1]) mem_array[dmem_addr[15:2]][15:8]  <= dmem_wdata[15:8];
      if (dmem_wstrb[2]) mem_array[dmem_addr[15:2]][23:16] <= dmem_wdata[23:16];
      if (dmem_wstrb[3]) mem_array[dmem_addr[15:2]][31:24] <= dmem_wdata[31:24];
    end
  end

  task check_reg(input int reg_num, input logic [31:0] exp_val, input string name);
    logic [31:0] actual;
    test_count++;
    actual = dut.u_regfile.rf[reg_num];
    if (actual !== exp_val) begin
      $display("[FAIL] %s: Reg x%0d EXP: 0x%08h (%0d) | GOT: 0x%08h (%0d)",
               name, reg_num, exp_val, $signed(exp_val), actual, $signed(actual));
      error_count++;
    end else begin
      $display("[PASS] %s: Reg x%0d == 0x%08h (%0d)",
               name, reg_num, actual, $signed(actual));
    end
  endtask

  initial begin
    clk   = 1'b0;
    rst_n = 1'b0;

    // Initialize memory with NOPs (addi x0, x0, 0)
    for (int i = 0; i < 16384; i++) begin
      mem_array[i] = 32'h0000_0013;
    end

    // -------------------------------------------------------------------------
    // Load Verification Program into Instruction Memory
    // -------------------------------------------------------------------------
    // 0x00: lui  x1, 0x00001           ; x1 = 0x0000_1000 (Data base address)
    mem_array[0]  = {20'h00001, 5'd1, 7'b0110111};

    // 0x04: addi x2, x0, 15            ; x2 = 15
    mem_array[1]  = {12'd15, 5'd0, 3'b000, 5'd2, 7'b0010011};

    // 0x08: addi x3, x0, 25            ; x3 = 25
    mem_array[2]  = {12'd25, 5'd0, 3'b000, 5'd3, 7'b0010011};

    // 0x0C: add  x4, x2, x3            ; x4 = 40 (RAW from x2, x3)
    mem_array[3]  = {7'b0000000, 5'd3, 5'd2, 3'b000, 5'd4, 7'b0110011};

    // 0x10: sub  x5, x4, x2            ; x5 = 40 - 15 = 25 (RAW from EX/MEM x4)
    mem_array[4]  = {7'b0100000, 5'd2, 5'd4, 3'b000, 5'd5, 7'b0110011};

    // 0x14: sw   x4, 0(x1)             ; Mem[0x1000] = 40
    mem_array[5]  = {7'b0000000, 5'd4, 5'd1, 3'b010, 5'b00000, 7'b0100011};

    // 0x18: lw   x6, 0(x1)             ; x6 = Mem[0x1000] = 40
    mem_array[6]  = {12'd0, 5'd1, 3'b010, 5'd6, 7'b0000011};

    // 0x1C: add  x7, x6, x2            ; x7 = 40 + 15 = 55 (LOAD-USE HAZARD on x6!)
    mem_array[7]  = {7'b0000000, 5'd2, 5'd6, 3'b000, 5'd7, 7'b0110011};

    // 0x20: beq  x4, x4, +8            ; Branch taken to 0x28 (skips 0x24)
    // offset +8: imm[12]=0, imm[11]=0, imm[10:5]=0, imm[4:1]=4'b0100
    mem_array[8]  = {1'b0, 6'b000000, 5'd4, 5'd4, 3'b000, 4'b0100, 1'b0, 7'b1100011};

    // 0x24: addi x8, x0, 99            ; MUST BE FLUSHED/SKIPPED!
    mem_array[9]  = {12'd99, 5'd0, 3'b000, 5'd8, 7'b0010011};

    // 0x28: addi x8, x0, 1             ; x8 = 1 (Target of branch)
    mem_array[10] = {12'd1, 5'd0, 3'b000, 5'd8, 7'b0010011};

    // 0x2C: addi x9, x0, -1            ; x9 = 0xFFFFFFFF
    mem_array[11] = {12'hFFF, 5'd0, 3'b000, 5'd9, 7'b0010011};

    // 0x30: sb   x9, 4(x1)             ; Mem[0x1004] byte 0 = 0xFF
    mem_array[12] = {7'b0000000, 5'd9, 5'd1, 3'b000, 5'b00100, 7'b0100011};

    // 0x34: lb   x10, 4(x1)            ; x10 = sign-extended byte = 0xFFFFFFFF
    mem_array[13] = {12'd4, 5'd1, 3'b000, 5'd10, 7'b0000011};

    // 0x38: lbu  x11, 4(x1)            ; x11 = zero-extended byte = 0x000000FF
    mem_array[14] = {12'd4, 5'd1, 3'b100, 5'd11, 7'b0000011};

    // 0x3C: jal  x12, +8               ; Jump to 0x44 (x12 = return address 0x40)
    // offset +8: imm[20]=0, imm[10:1]=4'b0100, imm[11]=0, imm[19:12]=0
    mem_array[15] = {1'b0, 10'b0000000100, 1'b0, 8'b00000000, 5'd12, 7'b1101111};

    // 0x40: addi x13, x0, 99           ; MUST BE FLUSHED/SKIPPED!
    mem_array[16] = {12'd99, 5'd0, 3'b000, 5'd13, 7'b0010011};

    // 0x44: addi x13, x0, 1            ; x13 = 1 (Target of JAL)
    mem_array[17] = {12'd1, 5'd0, 3'b000, 5'd13, 7'b0010011};

    // 0x48: jalr x14, 0(x12)           ; Jump to x12 (0x40), return to 0x4C (tests JALR)
    mem_array[18] = {12'd0, 5'd12, 3'b000, 5'd14, 7'b1100111};

    $display("\n========================================================");
    $display("       STARTING INTEGRATION TESTBENCH: tb_core");
    $display("========================================================");

    // Apply Reset
    #15;
    rst_n = 1'b1;

    // Run core for 40 clock cycles to complete execution
    repeat (40) @(posedge clk);
    #1;

    // -------------------------------------------------------------------------
    // Verification of Architectural State
    // -------------------------------------------------------------------------
    $display("\n--- [Step 1] Basic Arithmetic & Forwarding Verification ---");
    check_reg(1, 32'h0000_1000, "LUI x1 (Data Base)");
    check_reg(2, 32'd15,        "ADDI x2");
    check_reg(3, 32'd25,        "ADDI x3");
    check_reg(4, 32'd40,        "ADD x4 (15 + 25)");
    check_reg(5, 32'd25,        "SUB x5 (40 - 15 via Forwarding)");

    $display("\n--- [Step 2] Memory & Load-Use Hazard Verification ---");
    check_reg(6, 32'd40,        "LW x6 (Read 40 from Mem)");
    check_reg(7, 32'd55,        "ADD x7 (40 + 15 via Load-Use Stall)");

    $display("\n--- [Step 3] Branch Resolution & Flush Verification ---");
    check_reg(8, 32'd1,         "BEQ flush test (x8 == 1, not 99)");

    $display("\n--- [Step 4] Byte Store and Signed/Unsigned Load ---");
    check_reg(9,  32'hFFFF_FFFF, "ADDI x9 (-1)");
    check_reg(10, 32'hFFFF_FFFF, "LB x10 (Sign-extended 0xFF -> -1)");
    check_reg(11, 32'h0000_00FF, "LBU x11 (Zero-extended 0xFF -> 255)");

    $display("\n--- [Step 5] JAL Link and Target Redirection ---");
    check_reg(12, 32'h0000_0040, "JAL x12 Link Register (Return PC 0x40)");
    check_reg(13, 32'd1,         "JAL flush test (x13 == 1, not 99)");
    check_reg(14, 32'h0000_004C, "JALR x14 Link Register (Return PC 0x4C)");

    // -------------------------------------------------------------------------
    // Summary
    // -------------------------------------------------------------------------
    $display("\n========================================================");
    if (error_count == 0) begin
      $display(" >>> ALL %0d CORE INTEGRATION TESTS PASSED! <<<", test_count);
    end else begin
      $display(" >>> FAILED: %0d / %0d CORE TESTS FAILED! <<<", error_count, test_count);
    end
    $display("========================================================\n");
    $finish;
  end

endmodule : tb_core
