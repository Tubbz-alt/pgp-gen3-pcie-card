source -quiet $::env(RUCKUS_DIR)/vivado_proc.tcl
loadSource      -dir "$::DIR_PATH/rtl"
loadConstraints -dir "$::DIR_PATH/xdc"
