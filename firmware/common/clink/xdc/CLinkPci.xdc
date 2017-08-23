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
# PCIe: Physical Constraints #
##############################

# Area Constraint
create_pblock PCIE_GRP; add_cells_to_pblock [get_pblocks PCIE_GRP] [get_cells PciCore_Inst/PciFrontEnd_Inst/PcieCore_Inst]
resize_pblock [get_pblocks PCIE_GRP] -add {CLOCKREGION_X0Y2:CLOCKREGION_X0Y4}

############################
# PCIe: Timing Constraints #
############################
create_clock -period 10 -name pciRefClkP [get_ports pciRefClkP]
