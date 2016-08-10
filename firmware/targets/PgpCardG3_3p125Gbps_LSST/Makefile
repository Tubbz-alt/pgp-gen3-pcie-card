
# Define target output
target: prom

# Define target part
export PRJ_PART = XC7A200TFFG1156-3

# List of build core directories.
export MODULE_DIRS = $(PROJ_DIR)/../../modules/StdLib \
                     $(PROJ_DIR)/../../modules/MgtLib/gtp7/ \
                     $(PROJ_DIR)/../../modules/pgp2b/core \
                     $(PROJ_DIR)/../../modules/pgp2b/gtp7 \
                     $(PROJ_DIR)/../../modules/common/evr \
                     $(PROJ_DIR)/../../modules/common/general \
                     $(PROJ_DIR)/../../modules/common/pci \
                     $(PROJ_DIR)/../../modules/common/pgp \
                     $(PROJ_DIR)

# Use top level makefile
include ../../modules/StdLib/build/system_vivado_v1.mk
