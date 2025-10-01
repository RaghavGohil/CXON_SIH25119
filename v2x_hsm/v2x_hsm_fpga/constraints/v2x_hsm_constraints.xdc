# V2X HSM Constraints for Artix-7 XC7A35T
# System Clock - 100MHz
create_clock -period 10.000 -name sys_clk [get_ports i_sys_clk]

# SPI Interface
set_property PACKAGE_PIN M13 [get_ports i_spi_sclk]
set_property PACKAGE_PIN N14 [get_ports i_spi_mosi]
set_property PACKAGE_PIN M14 [get_ports o_spi_miso]
set_property PACKAGE_PIN L13 [get_ports i_spi_cs_n]

# System signals
set_property PACKAGE_PIN E3 [get_ports i_sys_clk]
set_property PACKAGE_PIN C12 [get_ports i_sys_rst_n]

# Status LEDs
set_property PACKAGE_PIN H17 [get_ports {o_status_leds[0]}]
set_property PACKAGE_PIN K15 [get_ports {o_status_leds[1]}]
set_property PACKAGE_PIN J13 [get_ports {o_status_leds[2]}]
set_property PACKAGE_PIN N14 [get_ports {o_status_leds[3]}]
set_property PACKAGE_PIN R18 [get_ports {o_status_leds[4]}]
set_property PACKAGE_PIN V17 [get_ports {o_status_leds[5]}]
set_property PACKAGE_PIN U17 [get_ports {o_status_leds[6]}]
set_property PACKAGE_PIN U16 [get_ports {o_status_leds[7]}]

# Operation and Error LEDs
set_property PACKAGE_PIN V16 [get_ports o_operation_led]
set_property PACKAGE_PIN T15 [get_ports o_error_led]

# IO Standards
set_property IOSTANDARD LVCMOS33 [get_ports i_sys_clk]
set_property IOSTANDARD LVCMOS33 [get_ports i_sys_rst_n]
set_property IOSTANDARD LVCMOS33 [get_ports i_spi_sclk]
set_property IOSTANDARD LVCMOS33 [get_ports i_spi_mosi]
set_property IOSTANDARD LVCMOS33 [get_ports o_spi_miso]
set_property IOSTANDARD LVCMOS33 [get_ports i_spi_cs_n]
set_property IOSTANDARD LVCMOS33 [get_ports o_status_leds]
set_property IOSTANDARD LVCMOS33 [get_ports o_operation_led]
set_property IOSTANDARD LVCMOS33 [get_ports o_error_led]

# Clock domain constraints
set_input_delay -clock [get_clocks sys_clk] -min 2.0 [get_ports {i_spi_sclk i_spi_mosi i_spi_cs_n}]
set_input_delay -clock [get_clocks sys_clk] -max 8.0 [get_ports {i_spi_sclk i_spi_mosi i_spi_cs_n}]
set_output_delay -clock [get_clocks sys_clk] -min 2.0 [get_ports o_spi_miso]
set_output_delay -clock [get_clocks sys_clk] -max 8.0 [get_ports o_spi_miso]
