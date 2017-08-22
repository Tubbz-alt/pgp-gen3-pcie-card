# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl


loadRuckusTcl $::env(PROJ_DIR)/../../submodules/surf
loadRuckusTcl $::env(PROJ_DIR)/../../common

loadSource      -dir  $::env(PROJ_DIR)/hdl
loadConstraints -path $::env(PROJ_DIR)/../../common/pgp/xdc/Pgp5p000Gbps.xdc
