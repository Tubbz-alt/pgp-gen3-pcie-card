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
# PGP: Timing Constraints #
###########################

create_clock -name pgpGtClk   -period 4.201 [get_pins {PgpCardG3Core_Inst/PgpCore_Inst/PgpClk_Inst/U_MMCM/OutBufgGen.ClkOutGen[0].U_Bufg/O}]
create_clock -name pgpTxClk   -period 4.201 [get_pins {PgpCardG3Core_Inst/PgpCore_Inst/PgpClk_Inst/U_MMCM/OutBufgGen.ClkOutGen[1].U_Bufg/O}]

create_clock -name pgpRxClk0 -period 4.201 [get_pins PgpCardG3Core_Inst/PgpCore_Inst/PgpFrontEnd_Inst/GEN_WEST[0].Pgp2bGtp7MultiLane_West/GTP7_CORE_GEN[0].Gtp7Core_Inst/gtpe2_i/RXOUTCLK]
create_clock -name pgpRxClk1 -period 4.201 [get_pins PgpCardG3Core_Inst/PgpCore_Inst/PgpFrontEnd_Inst/GEN_WEST[1].Pgp2bGtp7MultiLane_West/GTP7_CORE_GEN[0].Gtp7Core_Inst/gtpe2_i/RXOUTCLK]
create_clock -name pgpRxClk2 -period 4.201 [get_pins PgpCardG3Core_Inst/PgpCore_Inst/PgpFrontEnd_Inst/GEN_WEST[2].Pgp2bGtp7MultiLane_West/GTP7_CORE_GEN[0].Gtp7Core_Inst/gtpe2_i/RXOUTCLK]
create_clock -name pgpRxClk3 -period 4.201 [get_pins PgpCardG3Core_Inst/PgpCore_Inst/PgpFrontEnd_Inst/GEN_WEST[3].Pgp2bGtp7MultiLane_West/GTP7_CORE_GEN[0].Gtp7Core_Inst/gtpe2_i/RXOUTCLK]
create_clock -name pgpRxClk4 -period 4.201 [get_pins PgpCardG3Core_Inst/PgpCore_Inst/PgpFrontEnd_Inst/GEN_EAST[4].Pgp2bGtp7MultiLane_East/GTP7_CORE_GEN[0].Gtp7Core_Inst/gtpe2_i/RXOUTCLK]
create_clock -name pgpRxClk5 -period 4.201 [get_pins PgpCardG3Core_Inst/PgpCore_Inst/PgpFrontEnd_Inst/GEN_EAST[5].Pgp2bGtp7MultiLane_East/GTP7_CORE_GEN[0].Gtp7Core_Inst/gtpe2_i/RXOUTCLK]
create_clock -name pgpRxClk6 -period 4.201 [get_pins PgpCardG3Core_Inst/PgpCore_Inst/PgpFrontEnd_Inst/GEN_EAST[6].Pgp2bGtp7MultiLane_East/GTP7_CORE_GEN[0].Gtp7Core_Inst/gtpe2_i/RXOUTCLK]
create_clock -name pgpRxClk7 -period 4.201 [get_pins PgpCardG3Core_Inst/PgpCore_Inst/PgpFrontEnd_Inst/GEN_EAST[7].Pgp2bGtp7MultiLane_East/GTP7_CORE_GEN[0].Gtp7Core_Inst/gtpe2_i/RXOUTCLK]
