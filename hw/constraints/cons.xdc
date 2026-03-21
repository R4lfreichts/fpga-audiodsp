## Cora Z7-07S
## PS -> PL Audio Streaming

## Systemtakt 125 MHz
set_property -dict { PACKAGE_PIN H16 IOSTANDARD LVCMOS33 } [get_ports {clock_0}]
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports {clock_0}]

## Pmod Header JA
set_property -dict { PACKAGE_PIN Y18 IOSTANDARD LVCMOS33 } [get_ports {mclk_0[1]}]
set_property -dict { PACKAGE_PIN Y19 IOSTANDARD LVCMOS33 } [get_ports {ws_0[1]}]
set_property -dict { PACKAGE_PIN Y16 IOSTANDARD LVCMOS33 } [get_ports {sclk_0[1]}]
set_property -dict { PACKAGE_PIN Y17 IOSTANDARD LVCMOS33 } [get_ports {sd_tx_0}]

set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports {mclk_0[0]}]
set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } [get_ports {ws_0[0]}]
set_property -dict { PACKAGE_PIN W18 IOSTANDARD LVCMOS33 } [get_ports {sclk_0[0]}]

## Nur wenn der Port wirklich so heiﬂt:
set_property -dict { PACKAGE_PIN W19 IOSTANDARD LVCMOS33 } [get_ports {sd_rx}]

## underrun extern auf freien Pin
set_property -dict { PACKAGE_PIN Y14 IOSTANDARD LVCMOS33 } [get_ports {underrun_0}]