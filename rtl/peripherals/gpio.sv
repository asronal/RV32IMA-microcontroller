// =============================================================================
// File: gpio.sv
// Description: Minimal Memory-Mapped General Purpose I/O (GPIO) Peripheral
// Registers:
//   0x2000_1000 : DATA (R/W: Pin data read and write)
//   0x2000_1004 : DIR  (R/W: Pin direction / output enable: 1=Output, 0=Input)
// Standard: IEEE 1800-2017 SystemVerilog (Synthesizable for Synopsys DC)
// =============================================================================

`timescale 1ns / 1ps

module gpio #(
  parameter int GPIO_WIDTH = 8
)(
  input  logic                  clk,
  input  logic                  rst_n,

  // Bus Interface from bus_decoder
  input  logic                  en,
  input  logic                  we,
  input  logic [11:0]           addr,
  input  logic [31:0]           wdata,
  output logic [31:0]           rdata,

  // External Physical GPIO Pins
  input  logic [GPIO_WIDTH-1:0] gpio_in,
  output logic [GPIO_WIDTH-1:0] gpio_out,
  output logic [GPIO_WIDTH-1:0] gpio_oe
);

  localparam logic [11:0] REG_DATA = 12'h000;
  localparam logic [11:0] REG_DIR  = 12'h004;

  // ---------------------------------------------------------------------------
  // Input Pin Synchronizer (2-stage flip-flops against metastability)
  // ---------------------------------------------------------------------------
  logic [GPIO_WIDTH-1:0] in_sync1, in_sync2;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      in_sync1 <= '0;
      in_sync2 <= '0;
    end else begin
      in_sync1 <= gpio_in;
      in_sync2 <= in_sync1;
    end
  end

  // ---------------------------------------------------------------------------
  // Output and Direction Registers
  // ---------------------------------------------------------------------------
  logic [GPIO_WIDTH-1:0] out_reg;
  logic [GPIO_WIDTH-1:0] dir_reg;

  assign gpio_out = out_reg;
  assign gpio_oe  = dir_reg;

  // Synchronous Register Write
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      out_reg <= '0;
      dir_reg <= '0; // Default to all inputs (safe tri-state)
    end else if (en && we) begin
      case (addr)
        REG_DATA: out_reg <= wdata[GPIO_WIDTH-1:0];
        REG_DIR:  dir_reg <= wdata[GPIO_WIDTH-1:0];
        default: ;
      endcase
    end
  end

  // Combinational Register Read
  always_comb begin
    rdata = 32'd0;
    if (en && !we) begin
      case (addr)
        REG_DATA: begin
          // Input pins read when dir=0; output loopback read when dir=1
          rdata = {{(32-GPIO_WIDTH){1'b0}}, (in_sync2 & ~dir_reg) | (out_reg & dir_reg)};
        end
        REG_DIR: begin
          rdata = {{(32-GPIO_WIDTH){1'b0}}, dir_reg};
        end
        default: begin
          rdata = 32'd0;
        end
      endcase
    end
  end

endmodule : gpio
