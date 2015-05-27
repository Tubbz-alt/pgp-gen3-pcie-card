##############################
# PCIe: Physical Constraints #
##############################

# Area Constraint
create_pblock PCIE_GRP; add_cells_to_pblock [get_pblocks PCIE_GRP] [get_cells PgpCardG3Core_Inst/PciCore_Inst/PciFrontEnd_Inst/PcieCore_Inst]
resize_pblock [get_pblocks PCIE_GRP] -add {CLOCKREGION_X0Y2:CLOCKREGION_X0Y4}

############################
# PCIe: Timing Constraints #
############################
create_clock -period 10 -name pciRefClkP [get_ports pciRefClkP]
