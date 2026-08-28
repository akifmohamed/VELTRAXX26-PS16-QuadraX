# ==============================================================================
# SDC Timing Constraints for VELTRAXX'26 PS16 (QuadraX)
# Target Operating Clock: 50 MHz (20.0 ns Period)
# ==============================================================================

create_clock -name aclk -period 20.000 [get_ports aclk]

set_input_delay  -clock aclk 3.000 [all_inputs -no_clocks]
set_output_delay -clock aclk 3.000 [all_outputs]

set_clock_uncertainty 0.250 [get_clocks aclk]
set_clock_transition 0.150 [get_clocks aclk]
