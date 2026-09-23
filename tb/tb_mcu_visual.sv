// =============================================================================
// File: tb_mcu_visual.sv
// Description: Instrumented Visual Testbench with Cycle Logger & VCD Generation
// Standard: IEEE 1800-2017 SystemVerilog
// =============================================================================

`timescale 1ns / 1ps

module tb_mcu_visual;

  logic        clk;
  logic        rst_n;
  logic        uart_rx;
  logic        uart_tx;
  logic [7:0]  gpio_in;
  logic [7:0]  gpio_out;
  logic [7:0]  gpio_oe;

  localparam int SIM_CLK_HZ     = 10_000_000;
  localparam int SIM_BAUD       = 625_000;
  localparam int CYCLES_PER_BIT = SIM_CLK_HZ / SIM_BAUD;

  // Instantiate MCU
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

  // 10 MHz clock = 100ns period
  always #50 clk = ~clk;

  int cycle_count = 0;
  int log_file;

  // Background UART Receiver
  logic [7:0] rcv_chars [0:255];
  int rcv_count = 0;

  task automatic sample_uart_byte(output logic [7:0] data_out);
    logic [7:0] rcv;
    @(negedge uart_tx);
    repeat (CYCLES_PER_BIT / 2) @(posedge clk);
    for (int b = 0; b < 8; b++) begin
      repeat (CYCLES_PER_BIT) @(posedge clk);
      rcv[b] = uart_tx;
    end
    repeat (CYCLES_PER_BIT) @(posedge clk);
    data_out = rcv;
  endtask

  initial begin
    logic [7:0] b;
    forever begin
      sample_uart_byte(b);
      rcv_chars[rcv_count] = b;
      rcv_count++;
    end
  end

  initial begin
    clk     = 1'b0;
    rst_n   = 1'b0;
    uart_rx = 1'b1;
    gpio_in = 8'hAB;

    // Enable VCD Waveform generation
    $dumpfile("sim/mcu_waves.vcd");
    $dumpvars(0, tb_mcu_visual);

    log_file = $fopen("sim/sim_cycles.tsv", "w");
    // Write TSV Header
    $fwrite(log_file, "cycle\ttime_ns\tif_pc\tif_instr\tid_pc\tid_instr\tid_rs1\tid_rs2\tid_rd\tex_pc\tex_alu\tmem_pc\tdmem_addr\tdmem_wdata\tdmem_write\tdmem_rdata\tdmem_read\twb_rd\twb_we\twb_data\tstall\tflush\tfwd_a\tfwd_b\tbus_rom\tbus_ram\tbus_uart\tbus_gpio\tuart_tx\tuart_ready\tgpio_out\tgpio_oe\tgpio_in");
    for (int r = 0; r < 32; r++) begin
      $fwrite(log_file, "\tx%0d", r);
    end
    $fwrite(log_file, "\n");

    #100;
    rst_n = 1'b1;

    // Run until 12 characters received or 3000 cycles reached
    fork
      begin
        repeat (2500) @(posedge clk);
      end
      begin
        wait (rcv_count >= 12);
        // Run extra 200 cycles to capture GPIO manipulation
        repeat (200) @(posedge clk);
      end
    join_any
    disable fork;

    $fclose(log_file);
    $display("[INFO] Cycle trace dumped successfully (%0d cycles).", cycle_count);
    $display("[INFO] UART received %0d bytes: ", rcv_count);
    for (int i = 0; i < rcv_count; i++) begin
      $write("%s", string'(rcv_chars[i]));
    end
    $display("");
    $finish;
  end

  // Cycle logger
  always @(posedge clk) begin
    if (rst_n) begin
      cycle_count++;
      $fwrite(log_file, "%0d\t%0t\t%08h\t%08h\t%08h\t%08h\t%0d\t%0d\t%0d\t%08h\t%08h\t%08h\t%08h\t%08h\t%0b\t%08h\t%0b\t%0d\t%0b\t%08h\t%0b\t%0b\t%0d\t%0d\t%0b\t%0b\t%0b\t%0b\t%0b\t%0b\t%02h\t%02h\t%02h",
        cycle_count,
        $time / 1000,
        dut.u_rv32_core.pc_curr,
        dut.u_rv32_core.imem_rdata,
        dut.u_rv32_core.id_pc,
        dut.u_rv32_core.id_instr,
        dut.u_rv32_core.id_rs1_addr,
        dut.u_rv32_core.id_rs2_addr,
        dut.u_rv32_core.id_rd_addr,
        dut.u_rv32_core.ex_pc,
        dut.u_rv32_core.alu_result,
        dut.u_rv32_core.mem_pc,
        dut.u_rv32_core.dmem_addr,
        dut.u_rv32_core.dmem_wdata,
        dut.u_rv32_core.dmem_write,
        dut.u_rv32_core.dmem_rdata,
        dut.u_rv32_core.dmem_valid && !dut.u_rv32_core.dmem_write,
        dut.u_rv32_core.wb_rd_addr,
        dut.u_rv32_core.wb_reg_write,
        dut.u_rv32_core.wb_data,
        dut.u_rv32_core.stall_if_id,
        dut.u_rv32_core.flush_id_ex,
        dut.u_rv32_core.forward_a,
        dut.u_rv32_core.forward_b,
        dut.u_bus_decoder.rom_en,
        dut.u_bus_decoder.ram_en,
        dut.u_bus_decoder.uart_en,
        dut.u_bus_decoder.gpio_en,
        dut.uart_tx,
        dut.u_uart.tx_ready,
        dut.gpio_out,
        dut.gpio_oe,
        dut.u_gpio.in_sync2
      );

      for (int r = 0; r < 32; r++) begin
        $fwrite(log_file, "\t%08h", dut.u_rv32_core.u_regfile.rf[r]);
      end
      $fwrite(log_file, "\n");
    end
  end

endmodule : tb_mcu_visual
