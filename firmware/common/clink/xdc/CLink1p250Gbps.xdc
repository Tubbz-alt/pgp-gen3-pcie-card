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

create_clock -name pgpGtClk  -period 16.000 [get_pins {CLinkCore_Inst/ClClk_Inst/U_MMCM/OutBufgGen.ClkOutGen[0].U_Bufg/O}]
create_clock -name pgpTxClk  -period 16.000 [get_pins {CLinkCore_Inst/ClClk_Inst/U_MMCM/OutBufgGen.ClkOutGen[1].U_Bufg/O}]

create_clock -name pgpRxClk0 -period 16.000 [get_pins CLinkCore_Inst/GTP_WEST[0].Gtp7Core_Inst/gtpe2_i/RXOUTCLK]
create_clock -name pgpRxClk1 -period 16.000 [get_pins CLinkCore_Inst/GTP_WEST[1].Gtp7Core_Inst/gtpe2_i/RXOUTCLK]
create_clock -name pgpRxClk2 -period 16.000 [get_pins CLinkCore_Inst/GTP_WEST[2].Gtp7Core_Inst/gtpe2_i/RXOUTCLK]
create_clock -name pgpRxClk3 -period 16.000 [get_pins CLinkCore_Inst/GTP_WEST[3].Gtp7Core_Inst/gtpe2_i/RXOUTCLK]
create_clock -name pgpRxClk4 -period 16.000 [get_pins CLinkCore_Inst/GTP_EAST[4].Gtp7Core_Inst/gtpe2_i/RXOUTCLK]
create_clock -name pgpRxClk5 -period 16.000 [get_pins CLinkCore_Inst/GTP_EAST[5].Gtp7Core_Inst/gtpe2_i/RXOUTCLK]
create_clock -name pgpRxClk6 -period 16.000 [get_pins CLinkCore_Inst/GTP_EAST[6].Gtp7Core_Inst/gtpe2_i/RXOUTCLK]
create_clock -name pgpRxClk7 -period 16.000 [get_pins CLinkCore_Inst/GTP_EAST[7].Gtp7Core_Inst/gtpe2_i/RXOUTCLK]


