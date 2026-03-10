create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name clk_wiz_0

set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {125.000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {11.289} \
    CONFIG.NUM_OUT_CLKS {1} \
    CONFIG.RESET_TYPE {ACTIVE_LOW} \
] [get_ips clk_wiz_0]

generate_target all [get_ips clk_wiz_0]