#!/bin/sh

bitstream="$(dirname $0)/corev_apu/fpga/cva6_fpga.runs/impl_1/cva6_zybo_z7_20.bit"
if [ ! -f "${bitstream}" ]; then
    echo "Bitstream file does not exist."
fi

# To write the bitstream to the FLASH, use --write-flash
openFPGALoader --board arty --freq 10000000 --verbose-level -1 --write-sram "${bitstream}"
# New version use arty_a7_100t
