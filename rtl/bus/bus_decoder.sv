// =============================================================================
// File: bus_decoder.sv
// Description: Centralized Address Decoder & Memory-Mapped Bus Arbiter
// Memory Map:
//   0x0000_0000 - 0x0000_7FFF : Boot ROM (32 KB)
//   0x1000_0000 - 0x1000_7FFF : SRAM     (32 KB)
//   0x2000_0000 - 0x2000_0FFF : UART     (4 KB)
//   0x2000_1000 - 0x2000_1FFF : GPIO     (4 KB)
//   0x2000_2000 - 0x2000_2FFF : Reserved Timer Placeholder
// Standard: IEEE 1800-2017 SystemVerilog (Synthesizable for Synopsys DC)
// =============================================================================

`timescale 1ns / 1ps

module bus_decoder (
  // ---------------------------------------------------------------------------
  // Master Port: CPU Data Memory Interface
  // ---------------------------------------------------------------------------
  input  logic        dmem_valid,
  input  logic        dmem_write,
  input  logic [31:0] dmem_addr,
  input  logic [31:0] dmem_wdata,
  input  logic [3:0]  dmem_wstrb,
  output logic [31:0] dmem_rdata,
  output logic        dmem_ready,

  // ---------------------------------------------------------------------------
  // Slave Port 0: Boot ROM (Read Only)
  // ---------------------------------------------------------------------------
  output logic        rom_en,
  output logic [31:0] rom_addr,
  input  logic [31:0] rom_rdata,

  // ---------------------------------------------------------------------------
  // Slave Port 1: SRAM (Read / Write)
  // ---------------------------------------------------------------------------
  output logic        ram_en,
  output logic        ram_we,
  output logic [31:0] ram_addr,
  output logic [31:0] ram_wdata,
  output logic [3:0]  ram_wstrb,
  input  logic [31:0] ram_rdata,

  // ---------------------------------------------------------------------------
  // Slave Port 2: UART Controller
  // ---------------------------------------------------------------------------
  output logic        uart_en,
  output logic        uart_we,
  output logic [11:0] uart_addr,
  output logic [31:0] uart_wdata,
  input  logic [31:0] uart_rdata,

  // ---------------------------------------------------------------------------
  // Slave Port 3: GPIO Controller
  // ---------------------------------------------------------------------------
  output logic        gpio_en,
  output logic        gpio_we,
  output logic [11:0] gpio_addr,
  output logic [31:0] gpio_wdata,
  input  logic [31:0] gpio_rdata
);

  // ---------------------------------------------------------------------------
  // Address Region Decoding
  // ---------------------------------------------------------------------------
  logic sel_rom;
  logic sel_ram;
  logic sel_uart;
  logic sel_gpio;

  assign sel_rom  = (dmem_addr[31:15] == 17'b0_0000_0000_0000_0000); // 0x0000_0000 - 0x0000_7FFF (32KB)
  assign sel_ram  = (dmem_addr[31:28] == 4'b0001) &&
                    (dmem_addr[27:15] == 13'b0_0000_0000_0000);       // 0x1000_0000 - 0x1000_7FFF (32KB)
  assign sel_uart = (dmem_addr[31:12] == 20'h20000);                  // 0x2000_0000 - 0x2000_0FFF (4KB)
  assign sel_gpio = (dmem_addr[31:12] == 20'h20001);                  // 0x2000_1000 - 0x2000_1FFF (4KB)

  // ---------------------------------------------------------------------------
  // Slave Control Signal Generation
  // ---------------------------------------------------------------------------
  // ROM Interface
  assign rom_en   = dmem_valid && sel_rom;
  assign rom_addr = dmem_addr;

  // RAM Interface
  assign ram_en    = dmem_valid && sel_ram;
  assign ram_we    = dmem_write;
  assign ram_addr  = dmem_addr;
  assign ram_wdata = dmem_wdata;
  assign ram_wstrb = dmem_wstrb;

  // UART Interface
  assign uart_en    = dmem_valid && sel_uart;
  assign uart_we    = dmem_write;
  assign uart_addr  = dmem_addr[11:0];
  assign uart_wdata = dmem_wdata;

  // GPIO Interface
  assign gpio_en    = dmem_valid && sel_gpio;
  assign gpio_we    = dmem_write;
  assign gpio_addr  = dmem_addr[11:0];
  assign gpio_wdata = dmem_wdata;

  // ---------------------------------------------------------------------------
  // Read Data Multiplexing
  // ---------------------------------------------------------------------------
  always_comb begin
    if (sel_rom) begin
      dmem_rdata = rom_rdata;
    end else if (sel_ram) begin
      dmem_rdata = ram_rdata;
    end else if (sel_uart) begin
      dmem_rdata = uart_rdata;
    end else if (sel_gpio) begin
      dmem_rdata = gpio_rdata;
    end else begin
      dmem_rdata = 32'd0;
    end
  end

  // Synchronous bus handshake (zero wait-states)
  assign dmem_ready = 1'b1;

endmodule : bus_decoder
