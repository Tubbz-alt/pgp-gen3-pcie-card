# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl

# Load the Source Code
loadRuckusTcl $::env(PROJ_DIR)/../../submodules/surf
loadRuckusTcl $::env(PROJ_DIR)/../../common
loadRuckusTcl $::env(PROJ_DIR)/../../common/clink
loadSource      -dir  $::env(PROJ_DIR)/hdl

# Load the constraints
loadConstraints -path $::env(PROJ_DIR)/../../common/clink/xdc/CLinkEvr.xdc
loadConstraints -path $::env(PROJ_DIR)/../../common/clink/xdc/CLinkPci.xdc
loadConstraints -path $::env(PROJ_DIR)/../../common/clink/xdc/CLink2p500Gbps.xdc
loadConstraints -path $::env(PROJ_DIR)/../../common/clink/xdc/CLinkCore.xdc
loadConstraints -path $::env(PROJ_DIR)/../../common/general/xdc/PgpCardG3Pinout.xdc
