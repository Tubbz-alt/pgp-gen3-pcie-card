##############################################################################
## This file is part of 'SLAC PGP Gen3 Card'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC PGP Gen3 Card', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################

set_clock_groups -asynchronous \
   -group [get_clocks -of_objects [get_pins PgpCardG3Core_Inst/PgpCore_Inst/U_PgpV3FrontEnd/U_PGP_WEST/REAL_PGP.U_TX_PLL/PllGen.U_Pll/CLKOUT0]] \
   -group [get_clocks -of_objects [get_pins {PgpCardG3Core_Inst/PgpCore_Inst/U_PgpV3FrontEnd/U_PGP_WEST/REAL_PGP.GEN_LANE[0].U_Pgp/U_Pgp3Gtp7IpWrapper/U_RX_PLL/PllGen.U_Pll/CLKOUT0}]] \
   -group [get_clocks -of_objects [get_pins {PgpCardG3Core_Inst/PgpCore_Inst/U_PgpV3FrontEnd/U_PGP_WEST/REAL_PGP.GEN_LANE[0].U_Pgp/U_Pgp3Gtp7IpWrapper/U_RX_PLL/PllGen.U_Pll/CLKOUT2}]] \
   -group [get_clocks -of_objects [get_pins PgpCardG3Core_Inst/PciCore_Inst/PciFrontEnd_Inst/PcieCore_Inst/U0/inst/gt_top_i/pipe_wrapper_i/pipe_clock_int.pipe_clock_i/mmcm_i/CLKOUT3]] \
   -group [get_clocks -of_objects [get_pins PgpCardG3Core_Inst/PgpCore_Inst/U_PgpV3FrontEnd/U_PGP_WEST/INT_REFCLK.U_pgpRefClk/ODIV2]] \
   -group [get_clocks evrRxClk]

set_clock_groups -asynchronous \
   -group [get_clocks -of_objects [get_pins PgpCardG3Core_Inst/PgpCore_Inst/U_PgpV3FrontEnd/U_PGP_WEST/REAL_PGP.U_TX_PLL/PllGen.U_Pll/CLKOUT0]] \
   -group [get_clocks -of_objects [get_pins {PgpCardG3Core_Inst/PgpCore_Inst/U_PgpV3FrontEnd/U_PGP_WEST/REAL_PGP.GEN_LANE[1].U_Pgp/U_Pgp3Gtp7IpWrapper/U_RX_PLL/PllGen.U_Pll/CLKOUT0}]] \
   -group [get_clocks -of_objects [get_pins {PgpCardG3Core_Inst/PgpCore_Inst/U_PgpV3FrontEnd/U_PGP_WEST/REAL_PGP.GEN_LANE[1].U_Pgp/U_Pgp3Gtp7IpWrapper/U_RX_PLL/PllGen.U_Pll/CLKOUT2}]] \
   -group [get_clocks -of_objects [get_pins PgpCardG3Core_Inst/PciCore_Inst/PciFrontEnd_Inst/PcieCore_Inst/U0/inst/gt_top_i/pipe_wrapper_i/pipe_clock_int.pipe_clock_i/mmcm_i/CLKOUT3]] \
   -group [get_clocks -of_objects [get_pins PgpCardG3Core_Inst/PgpCore_Inst/U_PgpV3FrontEnd/U_PGP_WEST/INT_REFCLK.U_pgpRefClk/ODIV2]] \
   -group [get_clocks evrRxClk]
   
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins PgpCardG3Core_Inst/PgpCore_Inst/U_PgpV3FrontEnd/U_PGP_WEST/REAL_PGP.U_TX_PLL/PllGen.U_Pll/CLKOUT0]] -group [get_clocks -of_objects [get_pins PgpCardG3Core_Inst/PgpCore_Inst/U_PgpV3FrontEnd/U_PGP_WEST/REAL_PGP.U_TX_PLL/PllGen.U_Pll/CLKOUT2]]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins PgpCardG3Core_Inst/PgpCore_Inst/U_PgpV3FrontEnd/U_PGP_WEST/INT_REFCLK.U_pgpRefClk/ODIV2]] -group [get_clocks -of_objects [get_pins PgpCardG3Core_Inst/PgpCore_Inst/U_PgpV3FrontEnd/U_PGP_WEST/REAL_PGP.U_TX_PLL/PllGen.U_Pll/CLKOUT2]]   
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins PgpCardG3Core_Inst/PciCore_Inst/PciApp_Inst/DeviceDna_Inst/GEN_7SERIES.DeviceDna7Series_Inst/BUFR_Inst/O]] -group [get_clocks -of_objects [get_pins PgpCardG3Core_Inst/PciCore_Inst/PciApp_Inst/DeviceDna_Inst/GEN_7SERIES.DeviceDna7Series_Inst/DNA_CLK_INV_BUFR/O]]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins PgpCardG3Core_Inst/PciCore_Inst/PciApp_Inst/DeviceDna_Inst/GEN_7SERIES.DeviceDna7Series_Inst/DNA_CLK_INV_BUFR/O]] -group [get_clocks -of_objects [get_pins PgpCardG3Core_Inst/PciCore_Inst/PciFrontEnd_Inst/PcieCore_Inst/U0/inst/gt_top_i/pipe_wrapper_i/pipe_clock_int.pipe_clock_i/mmcm_i/CLKOUT3]]

set_clock_groups -asynchronous -group [get_clocks {PgpCardG3Core_Inst/PgpCore_Inst/U_PgpV3FrontEnd/U_PGP_WEST/REAL_PGP.GEN_LANE[0].U_Pgp/U_Pgp3Gtp7IpWrapper/GEN_6G.U_Pgp3Gtp7Ip6G/U0/Pgp3Gtp7Ip6G_i/gt0_Pgp3Gtp7Ip6G_i/gtpe2_i/RXOUTCLK}] -group [get_clocks -of_objects [get_pins PgpCardG3Core_Inst/PgpCore_Inst/U_PgpV3FrontEnd/U_PGP_WEST/INT_REFCLK.U_pgpRefClk/ODIV2]]
set_clock_groups -asynchronous -group [get_clocks {PgpCardG3Core_Inst/PgpCore_Inst/U_PgpV3FrontEnd/U_PGP_WEST/REAL_PGP.GEN_LANE[1].U_Pgp/U_Pgp3Gtp7IpWrapper/GEN_6G.U_Pgp3Gtp7Ip6G/U0/Pgp3Gtp7Ip6G_i/gt0_Pgp3Gtp7Ip6G_i/gtpe2_i/RXOUTCLK}] -group [get_clocks -of_objects [get_pins PgpCardG3Core_Inst/PgpCore_Inst/U_PgpV3FrontEnd/U_PGP_WEST/INT_REFCLK.U_pgpRefClk/ODIV2]]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins PgpCardG3Core_Inst/PgpCore_Inst/U_PgpV3FrontEnd/U_PGP_WEST/REAL_PGP.U_TX_PLL/PllGen.U_Pll/CLKOUT2]] -group [get_clocks -of_objects [get_pins PgpCardG3Core_Inst/PciCore_Inst/PciFrontEnd_Inst/PcieCore_Inst/U0/inst/gt_top_i/pipe_wrapper_i/pipe_clock_int.pipe_clock_i/mmcm_i/CLKOUT3]]

set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins PgpCardG3Core_Inst/PgpCore_Inst/U_PgpV3FrontEnd/U_PGP_WEST/INT_REFCLK.U_pgpRefClk/ODIV2]] -group [get_clocks -of_objects [get_pins PgpCardG3Core_Inst/PgpCore_Inst/U_PgpV3FrontEnd/U_PGP_WEST/REAL_PGP.U_TX_PLL/PllGen.U_Pll/CLKOUT1]]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins PgpCardG3Core_Inst/PgpCore_Inst/U_PgpV3FrontEnd/U_PGP_WEST/INT_REFCLK.U_pgpRefClk/ODIV2]] -group [get_clocks -of_objects [get_pins {PgpCardG3Core_Inst/PgpCore_Inst/U_PgpV3FrontEnd/U_PGP_WEST/REAL_PGP.GEN_LANE[0].U_Pgp/U_Pgp3Gtp7IpWrapper/U_RX_PLL/PllGen.U_Pll/CLKOUT1}]]
set_clock_groups -asynchronous -group [get_clocks -of_objects [get_pins PgpCardG3Core_Inst/PgpCore_Inst/U_PgpV3FrontEnd/U_PGP_WEST/INT_REFCLK.U_pgpRefClk/ODIV2]] -group [get_clocks -of_objects [get_pins {PgpCardG3Core_Inst/PgpCore_Inst/U_PgpV3FrontEnd/U_PGP_WEST/REAL_PGP.GEN_LANE[1].U_Pgp/U_Pgp3Gtp7IpWrapper/U_RX_PLL/PllGen.U_Pll/CLKOUT1}]]
