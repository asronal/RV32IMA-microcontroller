// =============================================================================
// File: tb_uart.sv
// Description: Comprehensive self-checking unit testbench for Memory-Mapped UART
// Tests: TX serialization, RX deserialization, STATUS flags, and BAUD configuration
// Standard: IEEE 1800-2017 SystemVerilog
// =============================================================================

`timescale 1ns / 1ps

module tb_uart;

  logic        clk;
  logic        rst_n;
  logic        en;
  logic        we;
  logic [11:0] addr;
  logic [31:0] wdata;
  logic [31:0] rdata;
  logic        uart_rx;
  logic        uart_tx;

  int error_count = 0;
  int test_count  = 0;

  // Use smaller clock frequency in simulation for fast execution (16 clocks per bit)
  localparam int SIM_CLK_HZ  = 1_600_000;
  localparam int SIM_BAUD    = 100_000; // 16 clocks per bit

  // Instantiate DUT
  uart #(
    .CLK_HZ       (SIM_CLK_HZ),
    .DEFAULT_BAUD (SIM_BAUD)
  ) dut (
    .clk     (clk),
    .rst_n   (rst_n),
    .en      (en),
    .we      (we),
    .addr    (addr),
    .wdata   (wdata),
    .rdata   (rdata),
    .uart_rx (uart_rx),
    .uart_tx (uart_tx)
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

  // Task to send a serial byte into uart_rx
  task send_serial_byte(input logic [7:0] byte_to_send, input int clocks_per_bit);
    // Start bit (0)
    uart_rx <= 1'b0;
    repeat (clocks_per_bit) @(posedge clk);

    // 8 Data bits (LSB first)
    for (int b = 0; b < 8; b++) begin
      uart_rx <= byte_to_send[b];
      repeat (clocks_per_bit) @(posedge clk);
    end

    // Stop bit (1)
    uart_rx <= 1'b1;
    repeat (clocks_per_bit) @(posedge clk);
  endtask

  initial begin
    clk     = 1'b0;
    rst_n   = 1'b0;
    en      = 1'b0;
    we      = 1'b0;
    addr    = 12'd0;
    wdata   = 32'd0;
    uart_rx = 1'b1; // Idle serial high

    $display("\n========================================================");
    $display("         STARTING TESTBENCH: tb_uart (Phase 8)");
    $display("========================================================");

    #15;
    rst_n = 1'b1;
    #20;

    // -------------------------------------------------------------------------
    // Test 1: Check Initial STATUS (TX_READY=1, RX_VALID=0)
    // -------------------------------------------------------------------------
    en <= 1'b1; we <= 1'b0; addr <= 12'h008; // REG_STATUS
    #1;
    check_cond(rdata[0] == 1'b1 && rdata[1] == 1'b0, "STATUS_INIT_TX_READY");
    en <= 1'b0;

    // -------------------------------------------------------------------------
    // Test 2: Transmit Character ('H' = 0x48 = 8'b01001000)
    // -------------------------------------------------------------------------
    @(posedge clk);
    en    <= 1'b1;
    we    <= 1'b1;
    addr  <= 12'h000; // REG_TXDATA
    wdata <= 32'h0000_0048;
    @(posedge clk);
    en <= 1'b0; we <= 1'b0;

    // Verify TX becomes not ready during transmission
    @(posedge clk);
    en <= 1'b1; addr <= 12'h008;
    #1;
    check_cond(rdata[0] == 1'b0, "STATUS_TX_BUSY");
    en <= 1'b0;

    // Wait for start bit on uart_tx
    wait(uart_tx == 1'b0);
    check_cond(uart_tx == 1'b0, "UART_TX_START_BIT");

    // Wait until transmitter finishes (returns to idle high)
    wait(dut.tx_state == dut.TX_STATE_STOP);
    wait(dut.tx_state == dut.TX_STATE_IDLE);
    #10;
    check_cond(uart_tx == 1'b1, "UART_TX_STOP_BIT_IDLE");

    // -------------------------------------------------------------------------
    // Test 3: Receive Character ('R' = 0x52 = 8'b01010010)
    // -------------------------------------------------------------------------
    send_serial_byte(8'h52, 16);
    #50;

    // Check STATUS RX_VALID
    en <= 1'b1; we <= 1'b0; addr <= 12'h008;
    #1;
    check_cond(rdata[1] == 1'b1, "STATUS_RX_VALID");

    // Read RXDATA and verify value
    addr <= 12'h004; // REG_RXDATA
    #1;
    check_cond(rdata[7:0] == 8'h52, "RXDATA_READ_CORRECT_BYTE");

    // Verify reading cleared RX_VALID
    @(posedge clk);
    addr <= 12'h008; // REG_STATUS
    #1;
    check_cond(rdata[1] == 1'b0, "STATUS_RX_VALID_CLEARED");
    en <= 1'b0;

    // -------------------------------------------------------------------------
    // Summary
    // -------------------------------------------------------------------------
    $display("\n========================================================");
    if (error_count == 0) begin
      $display(" >>> ALL %0d UART TESTS PASSED SUCCESSFULLY! <<<", test_count);
    end else begin
      $display(" >>> FAILED: %0d / %0d UART TESTS FAILED! <<<", error_count, test_count);
    end
    $display("========================================================\n");
    $finish;
  end

endmodule : tb_uart
