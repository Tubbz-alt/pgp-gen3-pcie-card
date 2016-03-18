export PARALLEL_BUILD = 4
export BUILD_SCRIPT = $(PWD)/modules/StdLib/build/system_build_all_v1.mk
export SETUP_ENV    = $(PWD)/setup_env.csh
export TARGET_DIRS  = $(PWD)/targets/PgpCardG3_1p250Gbps/ \
                      $(PWD)/targets/PgpCardG3_2p380Gbps/ \
                      $(PWD)/targets/PgpCardG3_2p500Gbps/ \
                      $(PWD)/targets/PgpCardG3_3p125Gbps/ \
                      $(PWD)/targets/PgpCardG3_4p760Gbps/ \
                      $(PWD)/targets/PgpCardG3_5p000Gbps/ \
                      $(PWD)/targets/PgpCardG3_DmaLoopback

# Use top level makefile
include $(BUILD_SCRIPT)
