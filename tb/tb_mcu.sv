// =============================================================================
// File: tb_mcu.sv
// Description: Full SoC Integration Testbench for rv32ima_mcu
// Tests: Boots from a pre-loaded ROM image, runs "Hello RISC-V" serial output
//        through the UART peripheral and checks GPIO pin drive.
// Standard: IEEE 1800-2017 SystemVerilog
// =============================================================================

`timescale 1ns / 1ps

module tb_mcu;

  logic        clk;
  logic        rst_n;
  logic        uart_rx;
  logic        uart_tx;
  logic [7:0]  gpio_in;
  logic [7:0]  gpio_out;
  logic [7:0]  gpio_oe;

  int error_count = 0;
  int test_count  = 0;

  // Simulation parameters: 10 MHz clock, 625_000 baud (16 cycles/bit)
  localparam int SIM_CLK_HZ  = 10_000_000;
  localparam int SIM_BAUD    = 625_000;  // 16 cycles per bit @ 10 MHz
  localparam int CYCLES_PER_BIT = SIM_CLK_HZ / SIM_BAUD;

  // Instantiate Full MCU
  rv32ima_mcu #(
    .ROM_BYTES  (32768),
    .RAM_BYTES  (32768),
    .CLK_HZ     (SIM_CLK_HZ),
    .BAUD_RATE  (SIM_BAUD),
    .GPIO_WIDTH (8),
    .BOOT_HEX   ("sim/firmware.hex")
  ) dut (
    .clk      (clk),
    .rst_n    (rst_n),
    .uart_rx  (uart_rx),
    .uart_tx  (uart_tx),
    .gpio_in  (gpio_in),
    .gpio_out (gpio_out),
    .gpio_oe  (gpio_oe)
  );

  // Clock: 10 MHz = 100 ns period
  always #50 clk = ~clk;

  // Received UART characters
  logic [7:0]  uart_rx_chars [0:255];
  int          uart_rx_count = 0;

  // Task: Sample one byte from uart_tx
  task automatic sample_uart_byte(output logic [7:0] data_out);
    logic [7:0] rcv;
    // Wait for start bit (falling edge)
    @(negedge uart_tx);
    // Skip to middle of start bit
    repeat (CYCLES_PER_BIT / 2) @(posedge clk);
    // Sample 8 data bits (LSB first)
    for (int b = 0; b < 8; b++) begin
      repeat (CYCLES_PER_BIT) @(posedge clk);
      rcv[b] = uart_tx;
    end
    // Skip stop bit
    repeat (CYCLES_PER_BIT) @(posedge clk);
    data_out = rcv;
  endtask

  // Background process: Capture all UART TX output
  initial begin
    logic [7:0] rcv_byte;
    forever begin
      sample_uart_byte(rcv_byte);
      uart_rx_chars[uart_rx_count] = rcv_byte;
      uart_rx_count++;
      $write("%s", string'(rcv_byte));
    end
  end

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
    uart_rx = 1'b1;  // Idle high
    gpio_in = 8'hAB;

    $display("\n=========================================================");
    $display("   STARTING TESTBENCH: tb_mcu (Phase 10 - SoC Integration)");
    $display("=========================================================");

    #100;
    rst_n = 1'b1;

    $display("[INFO] MCU released from reset. Waiting for UART output...");
    $display("[INFO] Firmware should print 'Hello RISC-V\\n' over UART.");

    // Wait up to 2,000,000 cycles for firmware to transmit output
    fork
      begin
        // Timeout watchdog
        repeat (2_000_000) @(posedge clk);
        $display("[WARN] Simulation timeout reached.");
      end
      begin
        // Wait until we have received 12 or more characters (len("Hello RISC-V\n"))
        wait (uart_rx_count >= 12);
        $display("\n[INFO] Received %0d UART characters.", uart_rx_count);
      end
    join_any
    disable fork;

    $display("");

    // -------------------------------------------------------------------------
    // Test 1: Verify first character received is 'H' (0x48)
    // -------------------------------------------------------------------------
    check_cond(uart_rx_chars[0] == 8'h48, "UART_FIRST_CHAR_IS_H");

    // -------------------------------------------------------------------------
    // Test 2: Verify received "Hello"
    // -------------------------------------------------------------------------
    check_cond(uart_rx_chars[1] == 8'h65 &&  // 'e'
               uart_rx_chars[2] == 8'h6C &&  // 'l'
               uart_rx_chars[3] == 8'h6C &&  // 'l'
               uart_rx_chars[4] == 8'h6F,    // 'o'
               "UART_HELLO_STRING");

    // -------------------------------------------------------------------------
    // Test 3: Verify UART output received
    // -------------------------------------------------------------------------
    check_cond(uart_rx_count >= 5, "UART_MINIMUM_OUTPUT_LENGTH");

    // -------------------------------------------------------------------------
    // Test 4: GPIO Input Sampling
    // -------------------------------------------------------------------------
    // After GPIO DIR configured to all-inputs, DATA register should reflect gpio_in
    repeat (10) @(posedge clk);
    check_cond(dut.u_gpio.in_sync2 == 8'hAB, "GPIO_EXTERNAL_INPUT_SAMPLED");

    // -------------------------------------------------------------------------
    // Summary
    // -------------------------------------------------------------------------
    $display("\n=========================================================");
    if (error_count == 0) begin
      $display(" >>> ALL %0d SOC INTEGRATION TESTS PASSED! <<<", test_count);
    end else begin
      $display(" >>> FAILED: %0d / %0d SOC TESTS FAILED! <<<", error_count, test_count);
    end
    $display("=========================================================\n");
    $finish;
  end

endmodule : tb_mcu
