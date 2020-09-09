export OVERRIDE_SUBMODULE_LOCKS = 1

# Define Firmware Version Number
export PRJ_VERSION = 0xDEAD0006

# Define target part
export PRJ_PART = XC7A200TFFG1156-3

# Define target output
target: vcs

# Define the TOP_DIR path
export TOP_DIR = $(abspath $(PWD)/../..)

# Use top level makefile
include $(TOP_DIR)/targets/common_config.mk
include $(TOP_DIR)/submodules/ruckus/system_vivado.mk
