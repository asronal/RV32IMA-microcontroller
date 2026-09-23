# =============================================================================
# File: constraints.sdc
# Description: Relaxed & Realistic Synthesis Constraints (SDC) for rv32ima_mcu
#              Targeting Synopsys Design Compiler with SAED PDK
# =============================================================================

# =============================================================================
# 1. Primary Clock Definition (50 MHz / 20 ns period)
# =============================================================================
create_clock -name CLK -period 20.0 -waveform {0 10} [get_ports clk]

# Declare clock and reset as ideal networks during logic synthesis
# (CTS and high-fanout reset buffering are handled in PnR, not in DC)
set_ideal_network [get_ports {clk rst_n}]
catch { set_dont_touch_network [get_clocks CLK] }

# Realistic clock uncertainty (setup: 150 ps, hold: 50 ps)
set_clock_uncertainty -setup 0.15 [get_clocks CLK]
set_clock_uncertainty -hold  0.05 [get_clocks CLK]

# Clock transition time
set_clock_transition 0.15 [get_clocks CLK]

# =============================================================================
# 2. Input / Output Delays (Relaxed & Realistic for MCU interfaces)
# =============================================================================
# Relaxed I/O delay budget (0.5 ns instead of aggressive 2.0 ns)
set INPUT_DELAY  0.5
set OUTPUT_DELAY 0.5

# Synchronous UART TX
set_output_delay $OUTPUT_DELAY -clock CLK [get_ports uart_tx]

# =============================================================================
# 3. False Paths (Asynchronous & Board-Level I/O)
# =============================================================================
# Reset is asynchronous chip reset; timing should not be constrained against data path
set_false_path -from [get_ports rst_n]

# UART RX has internal double-flop synchronizer
set_false_path -from [get_ports uart_rx]

# GPIOs are external, slow board-level pins (switches, buttons, LEDs)
set_false_path -from [get_ports gpio_in*]
set_false_path -to   [get_ports gpio_out*]
set_false_path -to   [get_ports gpio_oe*]

# =============================================================================
# 4. Drive Strength and Load Modeling
# =============================================================================
catch { set_driving_cell -lib_cell INVX1 [get_ports {rst_n uart_rx gpio_in*}] }
set_load 0.01 [get_ports {uart_tx gpio_out* gpio_oe*}]

# =============================================================================
# 5. Operating Conditions
# =============================================================================
catch { set_operating_conditions -max ss0p75v125c }

# =============================================================================
# 6. Optimization Directives (Relaxed: No artificial limits)
# =============================================================================
# set_max_area 0 is intentionally omitted to avoid aggressive gate downsizing
# set_max_fanout is omitted to let library DRC rules govern buffering
