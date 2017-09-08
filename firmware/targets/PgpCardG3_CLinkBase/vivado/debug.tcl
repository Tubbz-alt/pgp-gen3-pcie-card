##############################################################################
## This file is part of 'RCE Development Firmware'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'RCE Development Firmware', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################
set RUCKUS_DIR $::env(RUCKUS_DIR)
set IMAGENAME  $::env(IMAGENAME)
source -quiet ${RUCKUS_DIR}/vivado_env_var.tcl
source -quiet ${RUCKUS_DIR}/vivado_proc.tcl

## Open the run
open_run synth_1

# Get a list of nets
set netFile ${PROJ_DIR}/net_log.txt
set fd [open ${netFile} "w"]
set nl ""
append nl [get_nets {EvrCore_Inst/EvrApp_Inst/*}]
append nl [get_nets {PciCore_Inst/PciApp_Inst/*}]

regsub -all -line { } $nl "\n" nl
puts $fd $nl
close $fd

## Setup configurations
set ilaName u_ila_0

## Create the core
CreateDebugCore ${ilaName}

## Set the record depth
set_property C_DATA_DEPTH 8192 [get_debug_cores ${ilaName}]

## Set the clock for the Core
SetDebugCoreClk ${ilaName} {EvrCore_Inst/EvrApp_Inst/evrClk}

ConfigProbe ${ilaName} {EvrCore_Inst/EvrApp_Inst/got_code[0]_i_1_n_0}
ConfigProbe ${ilaName} {EvrCore_Inst/EvrApp_Inst/r[toCl][0][trigger]}
ConfigProbe ${ilaName} {EvrCore_Inst/EvrApp_Inst/fromPci[countRst]}
ConfigProbe ${ilaName} {EvrCore_Inst/EvrApp_Inst/fromPci[enable][*]}
ConfigProbe ${ilaName} {EvrCore_Inst/EvrApp_Inst/fromPci[evrReset]}
ConfigProbe ${ilaName} {EvrCore_Inst/EvrApp_Inst/fromPci[pllRst]}
ConfigProbe ${ilaName} {EvrCore_Inst/EvrApp_Inst/cycles[*]}
ConfigProbe ${ilaName} {EvrCore_Inst/EvrApp_Inst/prescale[0][*]_i_1_n_0}
ConfigProbe ${ilaName} {EvrCore_Inst/EvrApp_Inst/fromPci[trgDelay][0][*]}
ConfigProbe ${ilaName} {EvrCore_Inst/EvrApp_Inst/fromPci[trgCode][0][*]}
ConfigProbe ${ilaName} {EvrCore_Inst/EvrApp_Inst/fromPci[trgWidth][0][*]}
ConfigProbe ${ilaName} {EvrCore_Inst/EvrApp_Inst/enable[*]}

## Delete the last unused port
delete_debug_port [get_debug_ports [GetCurrentProbe ${ilaName}]]

## Write the port map file
write_debug_probes -force ${PROJ_DIR}/images/debug_probes_${IMAGENAME}.ltx

