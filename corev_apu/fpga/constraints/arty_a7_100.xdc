## Clock signal
# The clock will be created in the Clock Gen IP, no need to create it here.
# clk_sys is the 100MHz input clock.
set_property -dict { PACKAGE_PIN E3    IOSTANDARD LVCMOS33 } [get_ports clk_sys ];

## Buttons
# Button 0 is reset
set_property -dict { PACKAGE_PIN D9    IOSTANDARD LVCMOS33 } [get_ports cpu_reset ];

## USB-UART Interface (FTDI FT2232H)
# inverted
set_property -dict { PACKAGE_PIN D10   IOSTANDARD LVCMOS33  } [get_ports tx ];
set_property -dict { PACKAGE_PIN A9    IOSTANDARD LVCMOS33  } [get_ports rx ];

## JTAG
# minimize routing delay
set_max_delay -to [get_ports tdo] 20.000
set_max_delay -from [get_ports tms] 20.000
set_max_delay -from [get_ports tdi] 20.000
set_max_delay -from [get_ports trst_n] 20.000

# reset signal
set_false_path -from [get_ports trst_n]
