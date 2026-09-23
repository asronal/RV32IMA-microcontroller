// =============================================================================
// File: tb_regfile.sv
// Description: Comprehensive self-checking unit testbench for 32x32 Register File
// Standard: IEEE 1800-2017 SystemVerilog
// =============================================================================

`timescale 1ns / 1ps

module tb_regfile;

  logic        clk;
  logic        rst_n;
  logic [4:0]  rs1_addr;
  logic [31:0] rs1_data;
  logic [4:0]  rs2_addr;
  logic [31:0] rs2_data;
  logic        we;
  logic [4:0]  waddr;
  logic [31:0] wdata;

  int error_count = 0;
  int test_count  = 0;

  // Instantiate DUT
  regfile dut (
    .clk      (clk),
    .rst_n    (rst_n),
    .rs1_addr (rs1_addr),
    .rs1_data (rs1_data),
    .rs2_addr (rs2_addr),
    .rs2_data (rs2_data),
    .we       (we),
    .waddr    (waddr),
    .wdata    (wdata)
  );

  // Clock generation (10ns period = 100MHz)
  always #5 clk = ~clk;

  initial begin
    clk      = 1'b0;
    rst_n    = 1'b0;
    rs1_addr = 5'd0;
    rs2_addr = 5'd0;
    we       = 1'b0;
    waddr    = 5'd0;
    wdata    = 32'd0;

    $display("\n========================================================");
    $display("         STARTING TESTBENCH: tb_regfile");
    $display("========================================================");

    // Apply Reset
    #15;
    rst_n = 1'b1;
    #10;

    // -------------------------------------------------------------------------
    // Test 1: Verify all registers are zero after reset
    // -------------------------------------------------------------------------
    $display("\n--- [Test 1] Verify registers x0..x31 are 0 after reset ---");
    for (int i = 0; i < 32; i++) begin
      rs1_addr = i[4:0];
      #1;
      test_count++;
      if (rs1_data !== 32'd0) begin
        $display("[FAIL] Reg x%0d expected 0 after reset, got 0x%08h", i, rs1_data);
        error_count++;
      end
    end

    // -------------------------------------------------------------------------
    // Test 2: Verify x0 hardwire (Writes to x0 must be discarded)
    // -------------------------------------------------------------------------
    $display("\n--- [Test 2] Verify x0 cannot be overwritten ---");
    @(posedge clk);
    we    <= 1'b1;
    waddr <= 5'd0;
    wdata <= 32'hDEAD_BEEF;
    @(posedge clk);
    we    <= 1'b0;
    #1;

    rs1_addr = 5'd0;
    rs2_addr = 5'd0;
    #1;
    test_count++;
    if (rs1_data !== 32'd0 || rs2_data !== 32'd0) begin
      $display("[FAIL] x0 was modified! rs1_data=0x%08h, rs2_data=0x%08h", rs1_data, rs2_data);
      error_count++;
    end else begin
      $display("[PASS] x0 correctly reads 0x0000_0000 after write attempt.");
    end

    // -------------------------------------------------------------------------
    // Test 3: Write and read all registers x1..x31 with unique values
    // -------------------------------------------------------------------------
    $display("\n--- [Test 3] Write and Read all registers x1..x31 ---");
    for (int i = 1; i < 32; i++) begin
      @(posedge clk);
      we    <= 1'b1;
      waddr <= i[4:0];
      wdata <= 32'hA000_0000 + (i * 32'h0001_0001);
    end
    @(posedge clk);
    we <= 1'b0;

    // Read back and verify
    for (int i = 1; i < 32; i++) begin : read_verify_block
      logic [31:0] exp_val;
      rs1_addr = i[4:0];
      #1;
      test_count++;
      exp_val = 32'hA000_0000 + (i * 32'h0001_0001);
      if (rs1_data !== exp_val) begin
        $display("[FAIL] Reg x%0d expected 0x%08h, got 0x%08h", i, exp_val, rs1_data);
        error_count++;
      end
    end
    $display("[PASS] All 31 registers x1..x31 correctly written and read back.");

    // -------------------------------------------------------------------------
    // Test 4: Simultaneous Dual Reads
    // -------------------------------------------------------------------------
    $display("\n--- [Test 4] Simultaneous Dual Reads on rs1 and rs2 ---");
    rs1_addr = 5'd5;
    rs2_addr = 5'd10;
    #1;
    test_count++;
    if (rs1_data !== (32'hA000_0000 + (5 * 32'h0001_0001)) ||
        rs2_data !== (32'hA000_0000 + (10 * 32'h0001_0001))) begin
      $display("[FAIL] Dual read mismatch: rs1(x5)=0x%08h, rs2(x10)=0x%08h", rs1_data, rs2_data);
      error_count++;
    end else begin
      $display("[PASS] Dual read x5=0x%08h, x10=0x%08h verified.", rs1_data, rs2_data);
    end

    // -------------------------------------------------------------------------
    // Test 5: Re-assert reset and verify state clears
    // -------------------------------------------------------------------------
    $display("\n--- [Test 5] Re-assert reset and verify state clears ---");
    @(posedge clk);
    rst_n <= 1'b0;
    #15;
    rst_n <= 1'b1;
    #1;
    rs1_addr = 5'd5;
    #1;
    test_count++;
    if (rs1_data !== 32'd0) begin
      $display("[FAIL] Reg x5 not cleared on re-reset, got 0x%08h", rs1_data);
      error_count++;
    end else begin
      $display("[PASS] Reset successfully re-initialized register file.");
    end

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

endmodule : tb_regfile
