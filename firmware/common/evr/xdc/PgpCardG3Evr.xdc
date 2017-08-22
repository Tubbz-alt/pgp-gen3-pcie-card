##############################################################################
## This file is part of 'SLAC PGP Gen3 Card'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC PGP Gen3 Card', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################
###########################
# EVR: Timing Constraints #
###########################

create_clock -name evrRefClkP  -period 4.201 [get_ports evrRefClkP]
create_clock -name evrRefClk   -period 8.402 [get_pins {PgpCardG3Core_Inst/EvrCore_Inst/EvrClk_Inst/BUFG_Inst/O}]
create_clock -name evrRxClk    -period 8.402 [get_pins {PgpCardG3Core_Inst/EvrCore_Inst/EvrGtp7_Inst/Gtp7Core_Inst/gtpe2_i/RXOUTCLK}]

#############################
# EVR: Physical Constraints #
#############################

# # Area Constraint
# create_pblock EVR_GRP; add_cells_to_pblock [get_pblocks EVR_GRP] [get_cells [list PgpCardG3Core_Inst/EvrCore_Inst/EvrGtp7_Inst]]
# resize_pblock [get_pblocks EVR_GRP] -add {CLOCKREGION_X1Y3:CLOCKREGION_X1Y4}
