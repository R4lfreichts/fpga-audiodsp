create_ip -name clk_wiz -vendor xilinx.com -library ip -version 6.0 -module_name clk_wiz_0

set_property -dict [list \
    CONFIG.PRIM_IN_FREQ {125.000} \
    CONFIG.CLKOUT1_REQUESTED_OUT_FREQ {11.2896} \
    CONFIG.NUM_OUT_CLKS {1} \
    CONFIG.USE_RESET {true} \
    CONFIG.RESET_TYPE {ACTIVE_HIGH} \
    CONFIG.USE_LOCKED {true} \
] [get_ips clk_wiz_0]

generate_target all [get_ips clk_wiz_0]