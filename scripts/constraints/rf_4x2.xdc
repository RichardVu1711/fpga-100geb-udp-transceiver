## QSFP

set_property PACKAGE_PIN AA33 [ get_ports "gt_ref_clk_clk_p" ]
set_property PACKAGE_PIN AA34 [ get_ports "gt_ref_clk_clk_n" ]

set_property PACKAGE_PIN AL21     [ get_ports "qsfp_resetl" ]
set_property IOSTANDARD  LVCMOS18 [ get_ports "qsfp_resetl" ]
set_property PACKAGE_PIN AK22     [ get_ports "qsfp_modsell" ]
set_property IOSTANDARD  LVCMOS18 [ get_ports "qsfp_modsell" ]
set_property PACKAGE_PIN AN22     [ get_ports "qsfp_lpmode" ]
set_property IOSTANDARD  LVCMOS18 [ get_ports "qsfp_lpmode" ]

set_property BITSTREAM.CONFIG.UNUSEDPIN PULLUP [current_design]
set_property BITSTREAM.CONFIG.OVERTEMPSHUTDOWN ENABLE [current_design]
set_property BITSTREAM.GENERAL.COMPRESS TRUE [current_design]


# set_false_path -from [get_cells design_1_i/XCVC_inst/inst/xcvc_inst/eth_exp_reg*] \
#                -to   [get_clocks opclk_design_1_clk_wiz_0_0]

# set_false_path -from [get_cells -hier -filter {NAME =~ *eth_exp_reg*}] \
#                -to   [get_clocks opclk_design_1_clk_wiz_0_0]

# set_false_path -from [get_cells design_1_i/XCVC_inst/inst/xcvc_inst/ip4_exp_reg*] \
#                -to   [get_clocks opclk_design_1_clk_wiz_0_0]

# set_false_path -from [get_cells -hier -filter {NAME =~ *ip4_exp_reg*}] \
#                -to   [get_clocks opclk_design_1_clk_wiz_0_0]

# set_false_path -from [get_cells design_1_i/XCVC_inst/inst/xcvc_inst/udp_exp_reg*] \
#                -to   [get_clocks opclk_design_1_clk_wiz_0_0]

# set_false_path -from [get_cells -hier -filter {NAME =~ *udp_exp_reg*}] \
#                -to   [get_clocks opclk_design_1_clk_wiz_0_0]