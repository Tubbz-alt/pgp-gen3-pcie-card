# Load RUCKUS environment and library
source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl


loadRuckusTcl $::env(PROJ_DIR)/../../submodules/surf
loadRuckusTcl $::env(PROJ_DIR)/../../common

loadSource      -dir  $::env(PROJ_DIR)/hdl
loadConstraints -path $::env(PROJ_DIR)/../../modules/common/pgp/xdc/Pgp2p380Gbps.xdc

# Load local source Code and constraints

# Check if the partial reconfiguration not applied yet
if { [get_property PR_FLOW [current_project]] != 1 } {

   # Configure for partial reconfiguration
   set_property PR_FLOW 1 [current_project]

   #######################################################################################
   # Define the partial reconfiguration partitions
   # Note: TCL commands below were copied from GUI mode's TCL console 
   #      Refer to UG947 in section "Lab 2: UltraScale Basic Partial Reconfiguration Flow"
   #######################################################################################
   create_partition_def -name APP -module Application
   create_reconfig_module -name Application -partition_def [get_partition_defs APP ]  -define_from Application
   create_pr_configuration -name config_1 -partitions [list U_App:Application ]
   set_property PR_CONFIGURATION config_1 [get_runs impl_1]
}
