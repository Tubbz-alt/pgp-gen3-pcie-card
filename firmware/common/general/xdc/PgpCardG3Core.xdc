##############################################################################
## This file is part of 'SLAC PGP Gen3 Card'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC PGP Gen3 Card', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################
##############################
# StdLib: Custom Constraints #
##############################
set_property ASYNC_REG TRUE [get_cells -hierarchical *crossDomainSyncReg_reg*]

#############################
# PGP: Physical Constraints #
#############################

# create_pblock PGP_WEST_GRP; add_cells_to_pblock [get_pblocks PGP_WEST_GRP] [get_cells [list PgpCardG3Core_Inst/PgpCore_Inst/PgpFrontEnd_Inst/GEN_WEST*]]
# resize_pblock [get_pblocks PGP_WEST_GRP] -add {CLOCKREGION_X0Y0:CLOCKREGION_X0Y1}

# create_pblock PGP_EAST_GRP; add_cells_to_pblock [get_pblocks PGP_EAST_GRP] [get_cells [list PgpCardG3Core_Inst/PgpCore_Inst/PgpFrontEnd_Inst/GEN_EAST*]]
# resize_pblock [get_pblocks PGP_EAST_GRP] -add {CLOCKREGION_X1Y0:CLOCKREGION_X1Y1}

# create_pblock PGP_APP_GRP; add_cells_to_pblock [get_pblocks PGP_APP_GRP] [get_cells [list PgpCardG3Core_Inst/PgpCore_Inst/PgpApp_Inst]]
# resize_pblock [get_pblocks PGP_APP_GRP] -add {CLOCKREGION_X0Y1:CLOCKREGION_X1Y3}

######################
# Timing Constraints #
######################

create_clock -name pgpRefClk  -period  4.00 [get_ports pgpRefClkP]
create_clock -name sysClk     -period 20.00 [get_ports sysClk]
create_clock -name stableClk  -period 8.000 [get_pins {PgpCardG3Core_Inst/PgpCore_Inst/PgpClk_Inst/IBUFDS_GTE2_Inst/ODIV2}]

create_generated_clock  -name pciClk   [get_pins {PgpCardG3Core_Inst/PciCore_Inst/PciFrontEnd_Inst/PcieCore_Inst/U0/inst/gt_top_i/pipe_wrapper_i/pipe_clock_int.pipe_clock_i/mmcm_i/CLKOUT3}]
create_generated_clock  -name dnaClk   [get_pins {PgpCardG3Core_Inst/PciCore_Inst/PciApp_Inst/DeviceDna_Inst/GEN_7SERIES.DeviceDna7Series_Inst/BUFR_Inst/O}]

##############################################
# Crossing Domain Clocks: Timing Constraints #
##############################################

set_clock_groups -asynchronous -group [get_clocks {pgpTxClk}] \
                               -group [get_clocks {pgpRxClk*}] \
                               -group [get_clocks {stableClk}] \
                               -group [get_clocks {evrRefClk}] \
                               -group [get_clocks {evrRxClk}] 

set_clock_groups -asynchronous -group [get_clocks {pciClk}] -group [get_clocks {evrRxClk}]                                  
set_clock_groups -asynchronous -group [get_clocks {pciClk}] -group [get_clocks {pgpTxClk}] 
set_clock_groups -asynchronous -group [get_clocks {pciClk}] -group [get_clocks {dnaClk}]          
                                 
######################################
# BITSTREAM: .bit file Configuration #
######################################

set_property BITSTREAM.CONFIG.CONFIGRATE 50 [current_design]   
set_property BITSTREAM.CONFIG.BPI_SYNC_MODE Type2 [current_design]
set_property BITSTREAM.CONFIG.UNUSEDPIN Pullup [current_design]
set_property CONFIG_MODE BPI16 [current_design]
set_property CFGBVS VCCO [current_design]
set_property CONFIG_VOLTAGE 2.5 [current_design]                             
