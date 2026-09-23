# Synopsys, Inc. constraint file

# $Id: synpl.sdc 1055 2024-01-16 18:05:50Z angelov $:

#
# Collections
#

#
# Clocks
#
# PLL clock outputs, x4 clkin
#
define_clock   {t:pll_i.CLKOP}    -name {clock_sys}        -freq 36   -clockgroup gclock_sys
define_clock   {t:top_i.top_bus_i.config_i.sed_check_i.crc_check_i.SEDCLKOUT}   -name {clock_sed}   -freq 32   -clockgroup gclock_sed

#
# Clock to Clock
#

#
# Inputs/Outputs
#

#
# Registers
#

#
# Delay Paths
#

#
# Attributes
#

#
# I/O Standards
#

#
# Compile Points
#

#
# Other
#
