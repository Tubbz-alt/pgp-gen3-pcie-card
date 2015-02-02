##############################
# PCIe: Physical Constraints #
##############################

# BlockRAM placement (closest to PCIe HardCore)
set_property LOC RAMB36_X2Y46 [get_cells {PgpCardG3Core_Inst/PciCore_Inst/PciFrontEnd_Inst/PcieCore_Inst/U0/inst/pcie_top_i/pcie_7x_i/pcie_bram_top/pcie_brams_rx/brams[3].ram/use_tdp.ramb36/ramb_bl.ramb36_dp_bl.ram36_bl}]
set_property LOC RAMB36_X1Y47 [get_cells {PgpCardG3Core_Inst/PciCore_Inst/PciFrontEnd_Inst/PcieCore_Inst/U0/inst/pcie_top_i/pcie_7x_i/pcie_bram_top/pcie_brams_rx/brams[2].ram/use_tdp.ramb36/ramb_bl.ramb36_dp_bl.ram36_bl}]
set_property LOC RAMB36_X1Y46 [get_cells {PgpCardG3Core_Inst/PciCore_Inst/PciFrontEnd_Inst/PcieCore_Inst/U0/inst/pcie_top_i/pcie_7x_i/pcie_bram_top/pcie_brams_rx/brams[1].ram/use_tdp.ramb36/ramb_bl.ramb36_dp_bl.ram36_bl}]
set_property LOC RAMB36_X1Y45 [get_cells {PgpCardG3Core_Inst/PciCore_Inst/PciFrontEnd_Inst/PcieCore_Inst/U0/inst/pcie_top_i/pcie_7x_i/pcie_bram_top/pcie_brams_rx/brams[0].ram/use_tdp.ramb36/ramb_bl.ramb36_dp_bl.ram36_bl}]
set_property LOC RAMB36_X1Y44 [get_cells {PgpCardG3Core_Inst/PciCore_Inst/PciFrontEnd_Inst/PcieCore_Inst/U0/inst/pcie_top_i/pcie_7x_i/pcie_bram_top/pcie_brams_tx/brams[0].ram/use_tdp.ramb36/ramb_bl.ramb36_dp_bl.ram36_bl}]
set_property LOC RAMB36_X1Y43 [get_cells {PgpCardG3Core_Inst/PciCore_Inst/PciFrontEnd_Inst/PcieCore_Inst/U0/inst/pcie_top_i/pcie_7x_i/pcie_bram_top/pcie_brams_tx/brams[1].ram/use_tdp.ramb36/ramb_bl.ramb36_dp_bl.ram36_bl}]
set_property LOC RAMB36_X1Y42 [get_cells {PgpCardG3Core_Inst/PciCore_Inst/PciFrontEnd_Inst/PcieCore_Inst/U0/inst/pcie_top_i/pcie_7x_i/pcie_bram_top/pcie_brams_tx/brams[2].ram/use_tdp.ramb36/ramb_bl.ramb36_dp_bl.ram36_bl}]
set_property LOC RAMB36_X1Y41 [get_cells {PgpCardG3Core_Inst/PciCore_Inst/PciFrontEnd_Inst/PcieCore_Inst/U0/inst/pcie_top_i/pcie_7x_i/pcie_bram_top/pcie_brams_tx/brams[3].ram/use_tdp.ramb36/ramb_bl.ramb36_dp_bl.ram36_bl}]

# Area Constraint
create_pblock PCIE_GRP; add_cells_to_pblock [get_pblocks PCIE_GRP] [get_cells PgpCardG3Core_Inst/PciCore_Inst/PciFrontEnd_Inst/PcieCore_Inst]
resize_pblock [get_pblocks PCIE_GRP] -add {CLOCKREGION_X0Y2:CLOCKREGION_X0Y4}

############################
# PCIe: Timing Constraints #
############################
create_clock -period 10 -name pciRefClkP [get_ports pciRefClkP]

#
create_clock -period 10 [get_pins {PgpCardG3Core_Inst/PciCore_Inst/PciFrontEnd_Inst/PcieCore_Inst/U0/inst/gt_top_i/pipe_wrapper_i/pipe_lane[0].gt_wrapper_i/gtp_channel.gtpe2_channel_i/TXOUTCLK}]
#
#
set_false_path -to [get_pins {PgpCardG3Core_Inst/PciCore_Inst/PciFrontEnd_Inst/PcieCore_Inst/U0/inst/gt_top_i/pipe_wrapper_i/pipe_clock_int.pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/S0}]
set_false_path -to [get_pins {PgpCardG3Core_Inst/PciCore_Inst/PciFrontEnd_Inst/PcieCore_Inst/U0/inst/gt_top_i/pipe_wrapper_i/pipe_clock_int.pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/S1}]
#
#
create_generated_clock -name clk_125mhz_x0y0 [get_pins PgpCardG3Core_Inst/PciCore_Inst/PciFrontEnd_Inst/PcieCore_Inst/U0/inst/gt_top_i/pipe_wrapper_i/pipe_clock_int.pipe_clock_i/mmcm_i/CLKOUT0]
create_generated_clock -name clk_250mhz_x0y0 [get_pins PgpCardG3Core_Inst/PciCore_Inst/PciFrontEnd_Inst/PcieCore_Inst/U0/inst/gt_top_i/pipe_wrapper_i/pipe_clock_int.pipe_clock_i/mmcm_i/CLKOUT1]
create_generated_clock -name clk_125mhz_mux_x0y0 \
                        -source [get_pins PgpCardG3Core_Inst/PciCore_Inst/PciFrontEnd_Inst/PcieCore_Inst/U0/inst/gt_top_i/pipe_wrapper_i/pipe_clock_int.pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/I0] \
                        -divide_by 1 \
                        [get_pins PgpCardG3Core_Inst/PciCore_Inst/PciFrontEnd_Inst/PcieCore_Inst/U0/inst/gt_top_i/pipe_wrapper_i/pipe_clock_int.pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/O]
#
create_generated_clock -name clk_250mhz_mux_x0y0 \
                        -source [get_pins PgpCardG3Core_Inst/PciCore_Inst/PciFrontEnd_Inst/PcieCore_Inst/U0/inst/gt_top_i/pipe_wrapper_i/pipe_clock_int.pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/I1] \
                        -divide_by 1 -add -master_clock [get_clocks -of [get_pins PgpCardG3Core_Inst/PciCore_Inst/PciFrontEnd_Inst/PcieCore_Inst/U0/inst/gt_top_i/pipe_wrapper_i/pipe_clock_int.pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/I1]] \
                        [get_pins PgpCardG3Core_Inst/PciCore_Inst/PciFrontEnd_Inst/PcieCore_Inst/U0/inst/gt_top_i/pipe_wrapper_i/pipe_clock_int.pipe_clock_i/pclk_i1_bufgctrl.pclk_i1/O]
#
set_clock_groups -name pcieclkmux -physically_exclusive -group clk_125mhz_mux_x0y0 -group clk_250mhz_mux_x0y0
#
#

# Timing ignoring the below pins to avoid CDC analysis, but care has been taken in RTL to sync properly to other clock domain.
#
#
set_false_path -through [get_pins {PgpCardG3Core_Inst/PciCore_Inst/PciFrontEnd_Inst/PcieCore_Inst/U0/inst/pcie_top_i/pcie_7x_i/pcie_block_i/PLPHYLNKUPN}]
set_false_path -through [get_pins {PgpCardG3Core_Inst/PciCore_Inst/PciFrontEnd_Inst/PcieCore_Inst/U0/inst/pcie_top_i/pcie_7x_i/pcie_block_i/PLRECEIVEDHOTRST}]