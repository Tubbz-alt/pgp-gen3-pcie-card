##############################
# StdLib: Custom Constraints #
##############################
set_property ASYNC_REG TRUE [get_cells -hierarchical *crossDomainSyncReg_reg*]

#############################
# PGP: Physical Constraints #
#############################

create_pblock PGP_WEST_GRP; add_cells_to_pblock [get_pblocks PGP_WEST_GRP] [get_cells [list PgpCardG3Core_Inst/PgpCore_Inst/PgpFrontEnd_Inst/GEN_WEST*]]
resize_pblock [get_pblocks PGP_WEST_GRP] -add {CLOCKREGION_X0Y0:CLOCKREGION_X0Y1}

create_pblock PGP_EAST_GRP; add_cells_to_pblock [get_pblocks PGP_EAST_GRP] [get_cells [list PgpCardG3Core_Inst/PgpCore_Inst/PgpFrontEnd_Inst/GEN_EAST*]]
resize_pblock [get_pblocks PGP_EAST_GRP] -add {CLOCKREGION_X1Y0:CLOCKREGION_X1Y1}

create_pblock PGP_APP_GRP; add_cells_to_pblock [get_pblocks PGP_APP_GRP] [get_cells [list PgpCardG3Core_Inst/PgpCore_Inst/PgpApp_Inst]]
resize_pblock [get_pblocks PGP_APP_GRP] -add {CLOCKREGION_X0Y1:CLOCKREGION_X1Y3}

######################
# Timing Constraints #
######################

create_clock -name pgpRefClk  -period  4.00 [get_ports pgpRefClkP]
create_clock -name sysClk     -period 20.00 [get_ports sysClk]
create_clock -name stableClk  -period 8.000 [get_pins {PgpCardG3Core_Inst/PgpCore_Inst/PgpClk_Inst/IBUFDS_GTE2_Inst/ODIV2}]

create_generated_clock  -name pciClk [get_pins {PgpCardG3Core_Inst/PciCore_Inst/PciFrontEnd_Inst/PcieCore_Inst/U0/inst/gt_top_i/pipe_wrapper_i/pipe_clock_int.pipe_clock_i/mmcm_i/CLKOUT3}]
create_generated_clock  -name dnaClk [get_pins {PgpCardG3Core_Inst/PciCore_Inst/PciApp_Inst/Iprog7Series_Inst/DIVCLK_GEN.BUFR_ICPAPE2/O}]

##############################################
# Crossing Domain Clocks: Timing Constraints #
##############################################

set_clock_groups -asynchronous   -group [get_clocks {pgpTxClk}] \
                                 -group [get_clocks {pgpRxClk*}] \
                                 -group [get_clocks {stableClk}] \
                                 -group [get_clocks {evrRefClk}] \
                                 -group [get_clocks {evrRxClk}] 

set_clock_groups -asynchronous   -group [get_clocks {pciClk}] -group [get_clocks {evrRxClk}]                                  
set_clock_groups -asynchronous   -group [get_clocks {pciClk}] -group [get_clocks {pgpTxClk}] 
set_clock_groups -asynchronous   -group [get_clocks {pciClk}] -group [get_clocks {dnaClk}]                                  
                                 
######################################
# BITSTREAM: .bit file Configuration #
######################################

set_property BITSTREAM.CONFIG.CONFIGRATE 9 [current_design]                                 
