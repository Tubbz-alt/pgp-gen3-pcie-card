source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl
loadSource      -dir "$::DIR_PATH/rtl"
loadConstraints -dir "$::DIR_PATH/xdc"

loadSource   -path "$::DIR_PATH/ip/PcieCore4xA7.dcp"
# loadIpCore -path "$::DIR_PATH/ip/PcieCore4xA7.xci"