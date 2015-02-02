
###########################
# PGP: Timing Constraints #
###########################

create_clock -name pgpGtClk   -period 8.402 [get_pins PgpCardG3Core_Inst/PgpCore_Inst/PgpClk_Inst/BUFG_1/O]
create_clock -name pgpTxClk   -period 8.402 [get_pins PgpCardG3Core_Inst/PgpCore_Inst/PgpClk_Inst/BUFG_2/O]

create_clock -name pgpRxClk0 -period 8.402 [get_pins PgpCardG3Core_Inst/PgpCore_Inst/PgpFrontEnd_Inst/GEN_WEST[0].Pgp2bGtp7MultiLane_West/GTP7_CORE_GEN[0].Gtp7Core_Inst/gtpe2_i/RXOUTCLK]
create_clock -name pgpRxClk1 -period 8.402 [get_pins PgpCardG3Core_Inst/PgpCore_Inst/PgpFrontEnd_Inst/GEN_WEST[1].Pgp2bGtp7MultiLane_West/GTP7_CORE_GEN[0].Gtp7Core_Inst/gtpe2_i/RXOUTCLK]
create_clock -name pgpRxClk2 -period 8.402 [get_pins PgpCardG3Core_Inst/PgpCore_Inst/PgpFrontEnd_Inst/GEN_WEST[2].Pgp2bGtp7MultiLane_West/GTP7_CORE_GEN[0].Gtp7Core_Inst/gtpe2_i/RXOUTCLK]
create_clock -name pgpRxClk3 -period 8.402 [get_pins PgpCardG3Core_Inst/PgpCore_Inst/PgpFrontEnd_Inst/GEN_WEST[3].Pgp2bGtp7MultiLane_West/GTP7_CORE_GEN[0].Gtp7Core_Inst/gtpe2_i/RXOUTCLK]
create_clock -name pgpRxClk4 -period 8.402 [get_pins PgpCardG3Core_Inst/PgpCore_Inst/PgpFrontEnd_Inst/GEN_EAST[4].Pgp2bGtp7MultiLane_East/GTP7_CORE_GEN[0].Gtp7Core_Inst/gtpe2_i/RXOUTCLK]
create_clock -name pgpRxClk5 -period 8.402 [get_pins PgpCardG3Core_Inst/PgpCore_Inst/PgpFrontEnd_Inst/GEN_EAST[5].Pgp2bGtp7MultiLane_East/GTP7_CORE_GEN[0].Gtp7Core_Inst/gtpe2_i/RXOUTCLK]
create_clock -name pgpRxClk6 -period 8.402 [get_pins PgpCardG3Core_Inst/PgpCore_Inst/PgpFrontEnd_Inst/GEN_EAST[6].Pgp2bGtp7MultiLane_East/GTP7_CORE_GEN[0].Gtp7Core_Inst/gtpe2_i/RXOUTCLK]
create_clock -name pgpRxClk7 -period 8.402 [get_pins PgpCardG3Core_Inst/PgpCore_Inst/PgpFrontEnd_Inst/GEN_EAST[7].Pgp2bGtp7MultiLane_East/GTP7_CORE_GEN[0].Gtp7Core_Inst/gtpe2_i/RXOUTCLK]

