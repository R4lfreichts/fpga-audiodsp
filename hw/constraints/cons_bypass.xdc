## Cora Z7-07S Rev. B
## Pure-PL I2S bypass stage
## Top-level entity: bypass
##
## Active ports in bypass.vhd:
##   clock : in  std_logic
##   mclk  : out std_logic_vector(1 downto 0)
##   sclk  : out std_logic_vector(1 downto 0)
##   ws    : out std_logic_vector(1 downto 0)
##   sd_rx : in  std_logic
##   sd_tx : out std_logic
##
## Pmod I2S2 usage on JA:
##   JA[0-row] and JA[1-row] both receive the generated clocks.
##   sd_rx is the serial data coming back from the ADC/input path.
##   sd_tx is the serial data sent to the DAC/output path.
##
## Important hardware setting:
##   Set JP1 on the Pmod I2S2 to SLV so the FPGA provides the audio clocks.

## PL system clock, 125 MHz
set_property -dict { PACKAGE_PIN H16 IOSTANDARD LVCMOS33 } [get_ports { clock }]
create_clock -add -name sys_clk_pin -period 8.00 -waveform {0 4} [get_ports { clock }]

## Pmod Header JA
## Top row of Pmod JA
set_property -dict { PACKAGE_PIN Y18 IOSTANDARD LVCMOS33 } [get_ports { mclk[1] }]
set_property -dict { PACKAGE_PIN Y19 IOSTANDARD LVCMOS33 } [get_ports { ws[1] }]
set_property -dict { PACKAGE_PIN Y16 IOSTANDARD LVCMOS33 } [get_ports { sclk[1] }]
set_property -dict { PACKAGE_PIN Y17 IOSTANDARD LVCMOS33 } [get_ports { sd_tx }]

## Bottom row of Pmod JA
set_property -dict { PACKAGE_PIN U18 IOSTANDARD LVCMOS33 } [get_ports { mclk[0] }]
set_property -dict { PACKAGE_PIN U19 IOSTANDARD LVCMOS33 } [get_ports { ws[0] }]
set_property -dict { PACKAGE_PIN W18 IOSTANDARD LVCMOS33 } [get_ports { sclk[0] }]
set_property -dict { PACKAGE_PIN W19 IOSTANDARD LVCMOS33 } [get_ports { sd_rx }]
