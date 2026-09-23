// =============================================================================
// File: tb_memory.sv
// Description: Comprehensive self-checking unit testbench for Memory Subsystem
// Tests: bus_decoder, rom, ram, memory_wrapper
// Standard: IEEE 1800-2017 SystemVerilog
// =============================================================================

`timescale 1ns / 1ps

module tb_memory;

  logic        clk;
  logic        rst_n;

  // Master CPU bus signals
  logic        dmem_valid;
  logic        dmem_write;
  logic [31:0] dmem_addr;
  logic [31:0] dmem_wdata;
  logic [3:0]  dmem_wstrb;
  logic [31:0] dmem_rdata;
  logic        dmem_ready;

  // Peripheral mock signals
  logic [31:0] mock_uart_rdata;
  logic [31:0] mock_gpio_rdata;

  // Interconnect signals between bus_decoder and memory_wrapper
  logic        rom_en;
  logic [31:0] rom_addr;
  logic [31:0] rom_rdata;

  logic        ram_en;
  logic        ram_we;
  logic [31:0] ram_addr;
  logic [31:0] ram_wdata;
  logic [3:0]  ram_wstrb;
  logic [31:0] ram_rdata;

  logic        uart_en;
  logic        uart_we;
  logic [11:0] uart_addr;
  logic [31:0] uart_wdata;

  logic        gpio_en;
  logic        gpio_we;
  logic [11:0] gpio_addr;
  logic [31:0] gpio_wdata;

  // Instruction fetch signals to memory_wrapper
  logic        imem_en;
  logic [31:0] imem_addr;
  logic [31:0] imem_rdata;

  int error_count = 0;
  int test_count  = 0;

  // Clock generation (10ns period)
  always #5 clk = ~clk;

  // ---------------------------------------------------------------------------
  // Instantiate Bus Decoder
  // ---------------------------------------------------------------------------
  bus_decoder u_bus_decoder (
    .dmem_valid (dmem_valid),
    .dmem_write (dmem_write),
    .dmem_addr  (dmem_addr),
    .dmem_wdata (dmem_wdata),
    .dmem_wstrb (dmem_wstrb),
    .dmem_rdata (dmem_rdata),
    .dmem_ready (dmem_ready),
    .rom_en     (rom_en),
    .rom_addr   (rom_addr),
    .rom_rdata  (rom_rdata),
    .ram_en     (ram_en),
    .ram_we     (ram_we),
    .ram_addr   (ram_addr),
    .ram_wdata  (ram_wdata),
    .ram_wstrb  (ram_wstrb),
    .ram_rdata  (ram_rdata),
    .uart_en    (uart_en),
    .uart_we    (uart_we),
    .uart_addr  (uart_addr),
    .uart_wdata (uart_wdata),
    .uart_rdata (mock_uart_rdata),
    .gpio_en    (gpio_en),
    .gpio_we    (gpio_we),
    .gpio_addr  (gpio_addr),
    .gpio_wdata (gpio_wdata),
    .gpio_rdata (mock_gpio_rdata)
  );

  // ---------------------------------------------------------------------------
  // Instantiate Memory Wrapper
  // ---------------------------------------------------------------------------
  memory_wrapper #(
    .ROM_BYTES (32768),
    .RAM_BYTES (32768)
  ) u_memory_wrapper (
    .clk        (clk),
    .imem_en    (imem_en),
    .imem_addr  (imem_addr),
    .imem_rdata (imem_rdata),
    .rom_en     (rom_en),
    .rom_addr   (rom_addr),
    .rom_rdata  (rom_rdata),
    .ram_en     (ram_en),
    .ram_we     (ram_we),
    .ram_addr   (ram_addr),
    .ram_wdata  (ram_wdata),
    .ram_wstrb  (ram_wstrb),
    .ram_rdata  (ram_rdata)
  );

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
    clk             = 1'b0;
    rst_n           = 1'b0;
    dmem_valid      = 1'b0;
    dmem_write      = 1'b0;
    dmem_addr       = 32'd0;
    dmem_wdata      = 32'd0;
    dmem_wstrb      = 4'b0000;
    imem_en         = 1'b1;
    imem_addr       = 32'd0;
    mock_uart_rdata = 32'h0000_0001; // UART status ready
    mock_gpio_rdata = 32'h0000_00AA;

    $display("\n========================================================");
    $display("      STARTING TESTBENCH: tb_memory (Phase 7)");
    $display("========================================================");

    #15;
    rst_n = 1'b1;

    // -------------------------------------------------------------------------
    // Test 1: Instruction Fetch from Boot ROM
    // -------------------------------------------------------------------------
    imem_addr = 32'h0000_0000;
    #1;
    check_cond(imem_rdata == 32'h0000_0013, "ROM_FETCH_DEFAULT_NOP");

    // -------------------------------------------------------------------------
    // Test 2: Address Decoder routing to Boot ROM
    // -------------------------------------------------------------------------
    dmem_valid = 1'b1;
    dmem_write = 1'b0;
    dmem_addr  = 32'h0000_0010;
    #1;
    check_cond(rom_en && !ram_en && !uart_en && !gpio_en, "DECODE_ROM_REGION");

    // -------------------------------------------------------------------------
    // Test 3: Address Decoder routing to UART
    // -------------------------------------------------------------------------
    dmem_addr  = 32'h2000_0008; // UART STATUS register
    #1;
    check_cond(uart_en && !rom_en && !ram_en && !gpio_en && (dmem_rdata == 32'h0000_0001),
               "DECODE_UART_REGION");

    // -------------------------------------------------------------------------
    // Test 4: Address Decoder routing to GPIO
    // -------------------------------------------------------------------------
    dmem_addr  = 32'h2000_1000; // GPIO DATA register
    #1;
    check_cond(gpio_en && !rom_en && !ram_en && !uart_en && (dmem_rdata == 32'h0000_00AA),
               "DECODE_GPIO_REGION");

    // -------------------------------------------------------------------------
    // Test 5: SRAM Word Write and Read
    // -------------------------------------------------------------------------
    @(posedge clk);
    dmem_valid <= 1'b1;
    dmem_write <= 1'b1;
    dmem_addr  <= 32'h1000_0100;
    dmem_wdata <= 32'h1234_5678;
    dmem_wstrb <= 4'b1111;
    @(posedge clk);
    dmem_write <= 1'b0; // Read back
    #1;
    check_cond(ram_en && (dmem_rdata == 32'h1234_5678), "SRAM_FULL_WORD_WRITE_READ");

    // -------------------------------------------------------------------------
    // Test 6: SRAM Byte Write Strobes (Sub-word writes)
    // -------------------------------------------------------------------------
    // Write byte 0 = 0xAA
    @(posedge clk);
    dmem_write <= 1'b1;
    dmem_addr  <= 32'h1000_0200;
    dmem_wdata <= 32'h0000_00AA;
    dmem_wstrb <= 4'b0001;

    // Write byte 1 = 0xBB
    @(posedge clk);
    dmem_wdata <= 32'h0000_BB00;
    dmem_wstrb <= 4'b0010;

    // Write upper halfword = 0xDDCC
    @(posedge clk);
    dmem_wdata <= 32'hDDCC_0000;
    dmem_wstrb <= 4'b1100;

    // Read back entire word
    @(posedge clk);
    dmem_write <= 1'b0;
    #1;
    check_cond(dmem_rdata == 32'hDDCC_BBAA, "SRAM_BYTE_STROBE_ASSEMBLY");

    // -------------------------------------------------------------------------
    // Summary
    // -------------------------------------------------------------------------
    $display("\n========================================================");
    if (error_count == 0) begin
      $display(" >>> ALL %0d MEMORY & BUS TESTS PASSED! <<<", test_count);
    end else begin
      $display(" >>> FAILED: %0d / %0d MEMORY TESTS FAILED! <<<", error_count, test_count);
    end
    $display("========================================================\n");
    $finish;
  end

endmodule : tb_memory
