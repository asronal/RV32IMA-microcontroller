// =============================================================================
// File: tb_gpio.sv
// Description: Comprehensive self-checking unit testbench for GPIO Peripheral
// Tests: Direction control (DIR), Output drive (DATA), and Input sampling
// Standard: IEEE 1800-2017 SystemVerilog
// =============================================================================

`timescale 1ns / 1ps

module tb_gpio;

  localparam int GPIO_WIDTH = 8;

  logic                  clk;
  logic                  rst_n;
  logic                  en;
  logic                  we;
  logic [11:0]           addr;
  logic [31:0]           wdata;
  logic [31:0]           rdata;

  logic [GPIO_WIDTH-1:0] gpio_in;
  logic [GPIO_WIDTH-1:0] gpio_out;
  logic [GPIO_WIDTH-1:0] gpio_oe;

  int error_count = 0;
  int test_count  = 0;

  // Instantiate DUT
  gpio #(
    .GPIO_WIDTH(GPIO_WIDTH)
  ) dut (
    .clk      (clk),
    .rst_n    (rst_n),
    .en       (en),
    .we       (we),
    .addr     (addr),
    .wdata    (wdata),
    .rdata    (rdata),
    .gpio_in  (gpio_in),
    .gpio_out (gpio_out),
    .gpio_oe  (gpio_oe)
  );

  // Clock generation (10ns period)
  always #5 clk = ~clk;

  task check_cond(input logic cond, input string test_name);
    test_count++;
    if (!cond) begin
      $display("[FAIL] %s", test_name);
      error_count++;
    end else begin
      $display("[PASS] %s", test_name);
    end
  endtask

  initial begin
    clk     = 1'b0;
    rst_n   = 1'b0;
    en      = 1'b0;
    we      = 1'b0;
    addr    = 12'd0;
    wdata   = 32'd0;
    gpio_in = 8'h00;

    $display("\n========================================================");
    $display("         STARTING TESTBENCH: tb_gpio (Phase 9)");
    $display("========================================================");

    #15;
    rst_n = 1'b1;
    #10;

    // -------------------------------------------------------------------------
    // Test 1: Reset Defaults (All inputs, outputs zero)
    // -------------------------------------------------------------------------
    check_cond(gpio_oe == 8'h00 && gpio_out == 8'h00, "GPIO_RESET_DEFAULTS");

    // -------------------------------------------------------------------------
    // Test 2: Direction Register Write and Read
    // -------------------------------------------------------------------------
    @(posedge clk);
    en    <= 1'b1;
    we    <= 1'b1;
    addr  <= 12'h004; // REG_DIR
    wdata <= 32'h0000_000F; // Lower 4 pins outputs, Upper 4 inputs
    @(posedge clk);
    we    <= 1'b0;
    #1;
    check_cond(rdata[7:0] == 8'h0F && gpio_oe == 8'h0F, "GPIO_DIR_CONFIG");

    // -------------------------------------------------------------------------
    // Test 3: Output Data Drive
    // -------------------------------------------------------------------------
    @(posedge clk);
    we    <= 1'b1;
    addr  <= 12'h000; // REG_DATA
    wdata <= 32'h0000_0005; // Output pattern 4'b0101
    @(posedge clk);
    we    <= 1'b0;
    #1;
    check_cond(gpio_out == 8'h05, "GPIO_OUT_PINS_DRIVE");

    // -------------------------------------------------------------------------
    // Test 4: External Input Pin Sampling
    // -------------------------------------------------------------------------
    gpio_in <= 8'hA0; // Drive upper 4 pins with 4'b1010
    repeat (3) @(posedge clk); // Allow synchronizer to capture
    en   <= 1'b1;
    we   <= 1'b0;
    addr <= 12'h000;
    #1;
    // Lower 4 bits reflect output (0x5), upper 4 reflect input (0xA) -> 0xA5
    check_cond(rdata[7:0] == 8'hA5, "GPIO_INPUT_SAMPLING_A5");

    // -------------------------------------------------------------------------
    // Summary
    // -------------------------------------------------------------------------
    $display("\n========================================================");
    if (error_count == 0) begin
      $display(" >>> ALL %0d GPIO TESTS PASSED SUCCESSFULLY! <<<", test_count);
    end else begin
      $display(" >>> FAILED: %0d / %0d GPIO TESTS FAILED! <<<", error_count, test_count);
    end
    $display("========================================================\n");
    $finish;
  end

endmodule : tb_gpio
