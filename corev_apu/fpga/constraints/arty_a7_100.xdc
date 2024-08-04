## Clock signal
# The clock will be created in the Clock Gen IP, no need to create it here.
# clk_sys is the 100MHz input clock.
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports clk_sys ];

## Buttons
# Button 0 is reset
set_property -dict { PACKAGE_PIN D9    IOSTANDARD LVCMOS33 } [get_ports cpu_reset ];

## Pmod Header JD for FTDI FT2232 JTAG
# No srst_n pin is available in CVA6
set_property -dict { PACKAGE_PIN D4    IOSTANDARD LVCMOS33 } [get_ports tdo ];
set_property -dict { PACKAGE_PIN D3    IOSTANDARD LVCMOS33 } [get_ports trst_n ];
set_property -dict { PACKAGE_PIN F4    IOSTANDARD LVCMOS33 } [get_ports tck ];
set_property -dict { PACKAGE_PIN E2    IOSTANDARD LVCMOS33 } [get_ports tdi ];
set_property -dict { PACKAGE_PIN D2    IOSTANDARD LVCMOS33 } [get_ports tms ];

## USB-UART Interface (FTDI FT2232H)
# inverted
set_property -dict { PACKAGE_PIN D10   IOSTANDARD LVCMOS33  } [get_ports tx ];
set_property -dict { PACKAGE_PIN A9    IOSTANDARD LVCMOS33  } [get_ports rx ];

## Pmod Header JB
# set_property -dict { PACKAGE_PIN E15   IOSTANDARD LVCMOS33 } [get_ports rx ]; #IO_L11P_T1_SRCC_15 Sch=jb_p[1]
# set_property -dict { PACKAGE_PIN E16   IOSTANDARD LVCMOS33 } [get_ports tx ]; #IO_L11N_T1_SRCC_15 Sch=jb_n[1]
#set_property -dict { PACKAGE_PIN D15   IOSTANDARD LVCMOS33 } [get_ports { jb[2] }]; #IO_L12P_T1_MRCC_15 Sch=jb_p[2]
#set_property -dict { PACKAGE_PIN C15   IOSTANDARD LVCMOS33 } [get_ports { jb[3] }]; #IO_L12N_T1_MRCC_15 Sch=jb_n[2]
#set_property -dict { PACKAGE_PIN J17   IOSTANDARD LVCMOS33 } [get_ports { jb[4] }]; #IO_L23P_T3_FOE_B_15 Sch=jb_p[3]
#set_property -dict { PACKAGE_PIN J18   IOSTANDARD LVCMOS33 } [get_ports { jb[5] }]; #IO_L23N_T3_FWE_B_15 Sch=jb_n[3]
#set_property -dict { PACKAGE_PIN K15   IOSTANDARD LVCMOS33 } [get_ports { jb[6] }]; #IO_L24P_T3_RS1_15 Sch=jb_p[4]
#set_property -dict { PACKAGE_PIN J15   IOSTANDARD LVCMOS33 } [get_ports { jb[7] }]; #IO_L24N_T3_RS0_15 Sch=jb_n[4]

## JTAG
# minimize routing delay
set_max_delay -to [get_ports tdo] 20.000
set_max_delay -from [get_ports tms] 20.000
set_max_delay -from [get_ports tdi] 20.000
set_max_delay -from [get_ports trst_n] 20.000

# reset signal
set_false_path -from [get_ports trst_n]
