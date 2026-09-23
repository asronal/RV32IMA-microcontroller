// =============================================================================
// File: tb_atomic_unit.sv
// Description: Comprehensive self-checking unit testbench for Atomic Unit (RV32A)
// Standard: IEEE 1800-2017 SystemVerilog
// =============================================================================

`timescale 1ns / 1ps

module tb_atomic_unit;
  import rv32_pkg::*;

  logic        clk;
  logic        rst_n;
  logic        is_atomic;
  amo_op_e     amo_op;
  logic [31:0] mem_addr;
  logic [31:0] mem_rdata;
  logic [31:0] rs2_data;
  logic        store_valid;
  logic [31:0] store_addr;

  logic [31:0] amo_wdata;
  logic [31:0] amo_rdata;
  logic        amo_mem_write;
  logic        sc_success;
  logic        res_valid;
  logic [31:0] res_addr;

  int error_count = 0;
  int test_count  = 0;

  // Instantiate DUT
  atomic_unit dut (
    .clk           (clk),
    .rst_n         (rst_n),
    .is_atomic     (is_atomic),
    .amo_op        (amo_op),
    .mem_addr      (mem_addr),
    .mem_rdata     (mem_rdata),
    .rs2_data      (rs2_data),
    .store_valid   (store_valid),
    .store_addr    (store_addr),
    .amo_wdata     (amo_wdata),
    .amo_rdata     (amo_rdata),
    .amo_mem_write (amo_mem_write),
    .sc_success    (sc_success),
    .res_valid     (res_valid),
    .res_addr      (res_addr)
  );

  // Clock generation (10ns period)
  always #5 clk = ~clk;

  task check_out(
    input logic [31:0] exp_rdata,
    input logic [31:0] exp_wdata,
    input logic        exp_write,
    input logic        exp_sc_success,
    input string       test_name
  );
    #1;
    test_count++;
    if (amo_rdata !== exp_rdata || amo_wdata !== exp_wdata ||
        amo_mem_write !== exp_write || sc_success !== exp_sc_success) begin
      $display("[FAIL] %s | EXP: rd=0x%08h wd=0x%08h we=%b sc_ok=%b | GOT: rd=0x%08h wd=0x%08h we=%b sc_ok=%b",
               test_name, exp_rdata, exp_wdata, exp_write, exp_sc_success,
               amo_rdata, amo_wdata, amo_mem_write, sc_success);
      error_count++;
    end else begin
      $display("[PASS] %s: rd=0x%08h, wd=0x%08h, we=%b, sc_ok=%b",
               test_name, amo_rdata, amo_wdata, amo_mem_write, sc_success);
    end
  endtask

  initial begin
    clk         = 1'b0;
    rst_n       = 1'b0;
    is_atomic   = 1'b0;
    amo_op      = AMO_OP_NONE;
    mem_addr    = 32'd0;
    mem_rdata   = 32'd0;
    rs2_data    = 32'd0;
    store_valid = 1'b0;
    store_addr  = 32'd0;

    $display("\n========================================================");
    $display("      STARTING TESTBENCH: tb_atomic_unit (Phase 6)");
    $display("========================================================");

    // Apply Reset
    #15;
    rst_n = 1'b1;
    #10;

    // -------------------------------------------------------------------------
    // Test 1: Reset state
    // -------------------------------------------------------------------------
    if (res_valid !== 1'b0) begin
      $display("[FAIL] res_valid should be 0 after reset!");
      error_count++;
    end else begin
      $display("[PASS] Reset cleared reservation register.");
    end

    // -------------------------------------------------------------------------
    // Test 2: LR.W (Load-Reserved Word)
    // -------------------------------------------------------------------------
    @(posedge clk);
    is_atomic <= 1'b1;
    amo_op    <= AMO_OP_LR;
    mem_addr  <= 32'h1000_0000;
    mem_rdata <= 32'hDEAD_BEEF;
    check_out(32'hDEAD_BEEF, 32'd0, 1'b0, 1'b0, "LR.W_READ");

    @(posedge clk);
    #1;
    if (!res_valid || (res_addr !== 32'h1000_0000)) begin
      $display("[FAIL] LR.W failed to set reservation valid/address!");
      error_count++;
    end else begin
      $display("[PASS] LR.W successfully created reservation at 0x%08h.", res_addr);
    end

    // -------------------------------------------------------------------------
    // Test 3: SC.W with valid reservation (SUCCESS)
    // -------------------------------------------------------------------------
    amo_op   <= AMO_OP_SC;
    mem_addr <= 32'h1000_0000;
    rs2_data <= 32'hCAFE_BABE;
    check_out(32'd0, 32'hCAFE_BABE, 1'b1, 1'b1, "SC.W_SUCCESS");

    @(posedge clk);
    #1;
    if (res_valid !== 1'b0) begin
      $display("[FAIL] SC.W should invalidate reservation!");
      error_count++;
    end else begin
      $display("[PASS] SC.W cleared reservation after commit.");
    end

    // -------------------------------------------------------------------------
    // Test 4: SC.W without reservation (FAILURE)
    // -------------------------------------------------------------------------
    check_out(32'd1, 32'hCAFE_BABE, 1'b0, 1'b0, "SC.W_FAIL_NO_RESERVATION");

    // -------------------------------------------------------------------------
    // Test 5: SC.W address mismatch (FAILURE)
    // -------------------------------------------------------------------------
    // Set reservation at 0x2000
    amo_op   <= AMO_OP_LR;
    mem_addr <= 32'h2000_0000;
    @(posedge clk);
    #1;

    // Try SC to 0x2000_0004
    amo_op   <= AMO_OP_SC;
    mem_addr <= 32'h2000_0004;
    check_out(32'd1, 32'hCAFE_BABE, 1'b0, 1'b0, "SC.W_FAIL_ADDR_MISMATCH");

    // -------------------------------------------------------------------------
    // Test 6: Intervening store invalidation
    // -------------------------------------------------------------------------
    // Set reservation at 0x3000
    amo_op   <= AMO_OP_LR;
    mem_addr <= 32'h3000_0000;
    @(posedge clk);
    #1;

    // External store to 0x3000
    is_atomic   <= 1'b0;
    store_valid <= 1'b1;
    store_addr  <= 32'h3000_0000;
    @(posedge clk);
    store_valid <= 1'b0;
    #1;
    if (res_valid !== 1'b0) begin
      $display("[FAIL] Intervening store failed to clear reservation!");
      error_count++;
    end else begin
      $display("[PASS] Intervening store successfully invalidated reservation.");
    end

    // -------------------------------------------------------------------------
    // Test 7: AMOSWAP.W
    // -------------------------------------------------------------------------
    is_atomic <= 1'b1;
    amo_op    <= AMO_OP_SWAP;
    mem_rdata <= 32'h1234_5678;
    rs2_data  <= 32'h9876_5432;
    check_out(32'h1234_5678, 32'h9876_5432, 1'b1, 1'b0, "AMOSWAP.W");

    // -------------------------------------------------------------------------
    // Test 8: AMOADD.W
    // -------------------------------------------------------------------------
    amo_op    <= AMO_OP_ADD;
    mem_rdata <= 32'd100;
    rs2_data  <= 32'd50;
    check_out(32'd100, 32'd150, 1'b1, 1'b0, "AMOADD.W");

    // -------------------------------------------------------------------------
    // Test 9: AMOXOR.W, AMOAND.W, AMOOR.W
    // -------------------------------------------------------------------------
    amo_op    <= AMO_OP_XOR;
    mem_rdata <= 32'hFFFF_0000; rs2_data <= 32'hAAAA_AAAA;
    check_out(32'hFFFF_0000, 32'h5555_AAAA, 1'b1, 1'b0, "AMOXOR.W");

    amo_op    <= AMO_OP_AND;
    mem_rdata <= 32'hF0F0_F0F0; rs2_data <= 32'hFFFF_0000;
    check_out(32'hF0F0_F0F0, 32'hF0F0_0000, 1'b1, 1'b0, "AMOAND.W");

    amo_op    <= AMO_OP_OR;
    mem_rdata <= 32'hF0F0_0000; rs2_data <= 32'h0000_0F0F;
    check_out(32'hF0F0_0000, 32'hF0F0_0F0F, 1'b1, 1'b0, "AMOOR.W");

    // -------------------------------------------------------------------------
    // Test 10: AMOMIN.W & AMOMAX.W (Signed)
    // -------------------------------------------------------------------------
    amo_op    <= AMO_OP_MIN;
    mem_rdata <= -32'd10; rs2_data <= 32'd5;
    check_out(-32'd10, -32'd10, 1'b1, 1'b0, "AMOMIN.W_NEG");

    amo_op    <= AMO_OP_MAX;
    mem_rdata <= -32'd10; rs2_data <= 32'd5;
    check_out(-32'd10, 32'd5, 1'b1, 1'b0, "AMOMAX.W_POS");

    // -------------------------------------------------------------------------
    // Summary
    // -------------------------------------------------------------------------
    $display("\n========================================================");
    if (error_count == 0) begin
      $display(" >>> ALL %0d ATOMIC TESTS PASSED SUCCESSFULLY! <<<", test_count);
    end else begin
      $display(" >>> FAILED: %0d / %0d ATOMIC TESTS FAILED! <<<", error_count, test_count);
    end
    $display("========================================================\n");
    $finish;
  end

endmodule : tb_atomic_unit
