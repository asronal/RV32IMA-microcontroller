// =============================================================================
// File: uart.sv
// Description: Minimal Memory-Mapped UART Controller (8N1 Protocol)
// Registers:
//   0x2000_0000 : TXDATA  (W: Transmit byte [7:0])
//   0x2000_0004 : RXDATA  (R: Read received byte [7:0], clears RX_VALID)
//   0x2000_0008 : STATUS  (R: bit 0 = TX_READY, bit 1 = RX_VALID)
//   0x2000_000C : BAUD    (R/W: Clock divisor = CLK_HZ / BAUD_RATE)
// Standard: IEEE 1800-2017 SystemVerilog (Synthesizable for Synopsys DC)
// =============================================================================

`timescale 1ns / 1ps

module uart #(
  parameter int CLK_HZ       = 50_000_000,
  parameter int DEFAULT_BAUD = 115200
)(
  input  logic        clk,
  input  logic        rst_n,

  // Bus Interface from bus_decoder
  input  logic        en,
  input  logic        we,
  input  logic [11:0] addr,
  input  logic [31:0] wdata,
  output logic [31:0] rdata,

  // External Serial Pins
  input  logic        uart_rx,
  output logic        uart_tx
);

  // Default clock divisor (e.g. 50_000_000 / 115200 = 434)
  localparam int DEFAULT_DIVISOR = CLK_HZ / DEFAULT_BAUD;

  // ---------------------------------------------------------------------------
  // Register Map Offsets
  // ---------------------------------------------------------------------------
  localparam logic [11:0] REG_TXDATA = 12'h000;
  localparam logic [11:0] REG_RXDATA = 12'h004;
  localparam logic [11:0] REG_STATUS = 12'h008;
  localparam logic [11:0] REG_BAUD   = 12'h00C;

  // ---------------------------------------------------------------------------
  // Internal Control Registers
  // ---------------------------------------------------------------------------
  logic [15:0] baud_div;
  logic [7:0]  rx_buffer;
  logic        rx_valid;
  logic        tx_ready;

  // ---------------------------------------------------------------------------
  // 2-Stage Synchronizer for Asynchronous RX Input
  // ---------------------------------------------------------------------------
  logic rx_sync1, rx_sync2;
  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_sync1 <= 1'b1;
      rx_sync2 <= 1'b1;
    end else begin
      rx_sync1 <= uart_rx;
      rx_sync2 <= rx_sync1;
    end
  end

  // ---------------------------------------------------------------------------
  // Transmitter State Machine
  // ---------------------------------------------------------------------------
  typedef enum logic [1:0] {
    TX_STATE_IDLE  = 2'd0,
    TX_STATE_START = 2'd1,
    TX_STATE_DATA  = 2'd2,
    TX_STATE_STOP  = 2'd3
  } tx_state_e;

  tx_state_e    tx_state;
  logic [15:0]  tx_clk_cnt;
  logic [2:0]   tx_bit_cnt;
  logic [7:0]   tx_shift_reg;
  logic         tx_start_pulse;
  logic [7:0]   tx_byte_latch;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      tx_state       <= TX_STATE_IDLE;
      tx_clk_cnt     <= 16'd0;
      tx_bit_cnt     <= 3'd0;
      tx_shift_reg   <= 8'd0;
      tx_ready       <= 1'b1;
      uart_tx        <= 1'b1; // Idle line is high
    end else begin
      case (tx_state)
        TX_STATE_IDLE: begin
          uart_tx    <= 1'b1;
          tx_ready   <= 1'b1;
          tx_clk_cnt <= 16'd0;
          tx_bit_cnt <= 3'd0;
          if (tx_start_pulse) begin
            tx_shift_reg <= tx_byte_latch;
            tx_ready     <= 1'b0;
            tx_state     <= TX_STATE_START;
          end
        end

        TX_STATE_START: begin
          uart_tx <= 1'b0; // Start bit
          if (tx_clk_cnt >= baud_div - 1) begin
            tx_clk_cnt <= 16'd0;
            tx_state   <= TX_STATE_DATA;
          end else begin
            tx_clk_cnt <= tx_clk_cnt + 16'd1;
          end
        end

        TX_STATE_DATA: begin
          uart_tx <= tx_shift_reg[0];
          if (tx_clk_cnt >= baud_div - 1) begin
            tx_clk_cnt   <= 16'd0;
            tx_shift_reg <= {1'b0, tx_shift_reg[7:1]};
            if (tx_bit_cnt >= 3'd7) begin
              tx_state <= TX_STATE_STOP;
            end else begin
              tx_bit_cnt <= tx_bit_cnt + 3'd1;
            end
          end else begin
            tx_clk_cnt <= tx_clk_cnt + 16'd1;
          end
        end

        TX_STATE_STOP: begin
          uart_tx <= 1'b1; // Stop bit
          if (tx_clk_cnt >= baud_div - 1) begin
            tx_clk_cnt <= 16'd0;
            tx_state   <= TX_STATE_IDLE;
            tx_ready   <= 1'b1;
          end else begin
            tx_clk_cnt <= tx_clk_cnt + 16'd1;
          end
        end

        default: tx_state <= TX_STATE_IDLE;
      endcase
    end
  end

  // ---------------------------------------------------------------------------
  // Receiver State Machine
  // ---------------------------------------------------------------------------
  typedef enum logic [1:0] {
    RX_STATE_IDLE  = 2'd0,
    RX_STATE_START = 2'd1,
    RX_STATE_DATA  = 2'd2,
    RX_STATE_STOP  = 2'd3
  } rx_state_e;

  rx_state_e   rx_state;
  logic [15:0] rx_clk_cnt;
  logic [2:0]  rx_bit_cnt;
  logic [7:0]  rx_shift_reg;
  logic        rx_read_clear;

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      rx_state     <= RX_STATE_IDLE;
      rx_clk_cnt   <= 16'd0;
      rx_bit_cnt   <= 3'd0;
      rx_shift_reg <= 8'd0;
      rx_buffer    <= 8'd0;
      rx_valid     <= 1'b0;
    end else begin
      if (rx_read_clear) begin
        rx_valid <= 1'b0;
      end

      case (rx_state)
        RX_STATE_IDLE: begin
          rx_clk_cnt <= 16'd0;
          rx_bit_cnt <= 3'd0;
          if (!rx_sync2) begin // Falling edge of start bit
            rx_state <= RX_STATE_START;
          end
        end

        RX_STATE_START: begin
          // Wait 1.5 baud clocks to sample in middle of bit 0
          if (rx_clk_cnt >= (baud_div + (baud_div >> 1)) - 1) begin
            rx_clk_cnt   <= 16'd0;
            rx_shift_reg <= {rx_sync2, rx_shift_reg[7:1]};
            rx_state     <= RX_STATE_DATA;
          end else begin
            rx_clk_cnt <= rx_clk_cnt + 16'd1;
          end
        end

        RX_STATE_DATA: begin
          if (rx_clk_cnt >= baud_div - 1) begin
            rx_clk_cnt   <= 16'd0;
            rx_shift_reg <= {rx_sync2, rx_shift_reg[7:1]};
            if (rx_bit_cnt >= 3'd6) begin
              rx_state <= RX_STATE_STOP;
            end else begin
              rx_bit_cnt <= rx_bit_cnt + 3'd1;
            end
          end else begin
            rx_clk_cnt <= rx_clk_cnt + 16'd1;
          end
        end

        RX_STATE_STOP: begin
          if (rx_clk_cnt >= baud_div - 1) begin
            rx_clk_cnt <= 16'd0;
            if (rx_sync2) begin // Valid high stop bit
              rx_buffer <= rx_shift_reg;
              rx_valid  <= 1'b1;
            end
            rx_state <= RX_STATE_IDLE;
          end else begin
            rx_clk_cnt <= rx_clk_cnt + 16'd1;
          end
        end

        default: rx_state <= RX_STATE_IDLE;
      endcase
    end
  end

  // ---------------------------------------------------------------------------
  // Memory-Mapped Register Interface (Read / Write)
  // ---------------------------------------------------------------------------
  always_comb begin
    rdata          = 32'd0;
    rx_read_clear  = 1'b0;

    if (en && !we) begin
      case (addr)
        REG_TXDATA: rdata = 32'd0;
        REG_RXDATA: begin
          rdata         = {24'd0, rx_buffer};
          rx_read_clear = 1'b1;
        end
        REG_STATUS: begin
          rdata = {30'd0, rx_valid, tx_ready};
        end
        REG_BAUD: begin
          rdata = {16'd0, baud_div};
        end
        default: rdata = 32'd0;
      endcase
    end
  end

  always_ff @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      baud_div       <= 16'(DEFAULT_DIVISOR);
      tx_start_pulse <= 1'b0;
      tx_byte_latch  <= 8'd0;
    end else begin
      tx_start_pulse <= 1'b0;
      if (en && we) begin
        case (addr)
          REG_TXDATA: begin
            if (tx_ready) begin
              tx_byte_latch  <= wdata[7:0];
              tx_start_pulse <= 1'b1;
            end
          end
          REG_BAUD: begin
            if (wdata[15:0] > 16'd1) begin
              baud_div <= wdata[15:0];
            end
          end
          default: ;
        endcase
      end
    end
  end

endmodule : uart
