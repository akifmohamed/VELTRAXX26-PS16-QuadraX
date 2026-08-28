## ==============================================================================
## Basys3 Master XDC Constraints for VELTRAXX'26 PS16 (QuadraX)
## Target Device: xc7a35tcpg236-1
## ==============================================================================

## 100MHz System Clock from Oscillator
set_property PACKAGE_PIN W5 [get_ports aclk]							
set_property IOSTANDARD LVCMOS33 [get_ports aclk]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports aclk]

## Active-Low Reset Button (Center Button)
set_property PACKAGE_PIN U18 [get_ports aresetn]						
set_property IOSTANDARD LVCMOS33 [get_ports aresetn]

## Security Hardware IRQ / Tamper Output (Right Button / Header Pin)
set_property PACKAGE_PIN T17 [get_ports security_irq]						
set_property IOSTANDARD LVCMOS33 [get_ports security_irq]

## Status LEDs
set_property PACKAGE_PIN U16 [get_ports {led_data[0]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {led_data[0]}]
set_property PACKAGE_PIN E19 [get_ports {led_data[1]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {led_data[1]}]
set_property PACKAGE_PIN U19 [get_ports {led_data[2]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {led_data[2]}]
set_property PACKAGE_PIN V19 [get_ports {led_data[3]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {led_data[3]}]
set_property PACKAGE_PIN W18 [get_ports {led_data[4]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {led_data[4]}]
set_property PACKAGE_PIN U15 [get_ports {led_data[5]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {led_data[5]}]
set_property PACKAGE_PIN U14 [get_ports {led_data[6]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {led_data[6]}]
set_property PACKAGE_PIN V14 [get_ports {led_data[7]}]					
set_property IOSTANDARD LVCMOS33 [get_ports {led_data[7]}]

set_property PACKAGE_PIN V13 [get_ports led_busy]					
set_property IOSTANDARD LVCMOS33 [get_ports led_busy]
set_property PACKAGE_PIN V3  [get_ports led_done]					
set_property IOSTANDARD LVCMOS33 [get_ports led_done]
set_property PACKAGE_PIN W3  [get_ports led_fault]					
set_property IOSTANDARD LVCMOS33 [get_ports led_fault]
