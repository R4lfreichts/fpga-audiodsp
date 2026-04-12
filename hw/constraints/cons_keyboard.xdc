## Cora Z7-07S
## I2S Sinusgenerator

## Systemtakt 125 MHz
set_property -dict { PACKAGE_PIN H16 IOSTANDARD LVCMOS33 } [get_ports {clock}]
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports {clock}]

## Pmod Header JA
set_property -dict { PACKAGE_PIN Y18 IOSTANDARD LVCMOS33 } [get_ports {mclk[1]}]
set_property -dict { PACKAGE_PIN Y19 IOSTANDARD LVCMOS33 } [get_ports {ws[1]}]
set_property -dict { PACKAGE_PIN Y16 IOSTANDARD LVCMOS33 } [get_ports {sclk[1]}]
set_property -dict { PACKAGE_PIN Y17 IOSTANDARD LVCMOS33 } [get_ports {sd_tx}]

set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports {mclk[0]}]
set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } [get_ports {ws[0]}]
set_property -dict { PACKAGE_PIN W18 IOSTANDARD LVCMOS33 } [get_ports {sclk[0]}]
set_property -dict { PACKAGE_PIN W19 IOSTANDARD LVCMOS33 } [get_ports {sd_rx}]

## Buttons
set_property -dict { PACKAGE_PIN D20 IOSTANDARD LVCMOS33 } [get_ports {btn_l}]
set_property -dict { PACKAGE_PIN D19 IOSTANDARD LVCMOS33 } [get_ports {btn_r}]