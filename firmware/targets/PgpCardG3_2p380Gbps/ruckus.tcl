# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load the Source Code
loadRuckusTcl $::env(PROJ_DIR)/../../submodules/surf
loadRuckusTcl $::env(PROJ_DIR)/../../common
loadSource      -dir  $::env(PROJ_DIR)/hdl

# Load the constraints
loadConstraints -path $::env(PROJ_DIR)/../../common/evr/xdc/PgpCardG3Evr.xdc
loadConstraints -path $::env(PROJ_DIR)/../../common/pci/xdc/PgpCardG3Pci.xdc
loadConstraints -path $::env(PROJ_DIR)/../../common/pgp/xdc/Pgp2p380Gbps.xdc
loadConstraints -path $::env(PROJ_DIR)/../../common/general/xdc/PgpCardG3Core.xdc
loadConstraints -path $::env(PROJ_DIR)/../../common/general/xdc/PgpCardG3Pinout.xdc
