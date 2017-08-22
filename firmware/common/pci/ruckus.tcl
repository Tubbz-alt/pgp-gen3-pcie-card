source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl
loadSource      -dir "$::DIR_PATH/rtl"
loadSource   -path "$::DIR_PATH/ip/PcieCore4xA7.dcp"
# loadIpCore -path "$::DIR_PATH/ip/PcieCore4xA7.xci"