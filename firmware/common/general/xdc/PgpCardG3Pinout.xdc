##############################################################################
## This file is part of 'SLAC PGP Gen3 Card'.
## It is subject to the license terms in the LICENSE.txt file found in the 
## top-level directory of this distribution and at: 
##    https://confluence.slac.stanford.edu/display/ppareg/LICENSE.html. 
## No part of 'SLAC PGP Gen3 Card', including this file, 
## may be copied, modified, propagated, or distributed except according to 
## the terms contained in the LICENSE.txt file.
##############################################################################
##############################
# System: Pinout Constraints #
##############################

set_property PACKAGE_PIN Y31  [get_ports led[0]]
set_property PACKAGE_PIN AA30 [get_ports led[1]]
set_property PACKAGE_PIN AB30 [get_ports led[2]]
set_property PACKAGE_PIN AB31 [get_ports led[3]]
set_property PACKAGE_PIN AB32 [get_ports led[4]]
set_property PACKAGE_PIN AC33 [get_ports led[5]]
set_property PACKAGE_PIN AC34 [get_ports led[6]]
set_property PACKAGE_PIN AA32 [get_ports led[7]]
set_property IOSTANDARD LVCMOS25 [get_ports led[*]]

set_property PACKAGE_PIN AB25 [get_ports flashAddr[0]]
set_property PACKAGE_PIN AB24 [get_ports flashAddr[1]]
set_property PACKAGE_PIN AA25 [get_ports flashAddr[2]]
set_property PACKAGE_PIN AA24 [get_ports flashAddr[3]]
set_property PACKAGE_PIN AB29 [get_ports flashAddr[4]]
set_property PACKAGE_PIN AA29 [get_ports flashAddr[5]]
set_property PACKAGE_PIN AB27 [get_ports flashAddr[6]]
set_property PACKAGE_PIN AA28 [get_ports flashAddr[7]]
set_property PACKAGE_PIN AA27 [get_ports flashAddr[8]]
set_property PACKAGE_PIN AC29 [get_ports flashAddr[9]]
set_property PACKAGE_PIN AC28 [get_ports flashAddr[10]]
set_property PACKAGE_PIN AB34 [get_ports flashAddr[11]]
set_property PACKAGE_PIN AA34 [get_ports flashAddr[12]]
set_property PACKAGE_PIN AC32 [get_ports flashAddr[13]]
set_property PACKAGE_PIN AC31 [get_ports flashAddr[14]]
set_property PACKAGE_PIN AA33 [get_ports flashAddr[15]]
set_property PACKAGE_PIN M34  [get_ports flashAddr[16]]
set_property PACKAGE_PIN N34  [get_ports flashAddr[17]]
set_property PACKAGE_PIN R33  [get_ports flashAddr[18]]
set_property PACKAGE_PIN N33  [get_ports flashAddr[19]]
set_property PACKAGE_PIN N32  [get_ports flashAddr[20]]
set_property PACKAGE_PIN R32  [get_ports flashAddr[21]]
set_property PACKAGE_PIN T32  [get_ports flashAddr[22]]
set_property PACKAGE_PIN U32  [get_ports flashAddr[23]]
set_property PACKAGE_PIN U31  [get_ports flashAddr[24]]
set_property PACKAGE_PIN M32  [get_ports flashAddr[25]]
set_property IOSTANDARD LVCMOS25 [get_ports flashAddr[*]]

set_property PACKAGE_PIN V28 [get_ports flashData[0]]
set_property PACKAGE_PIN V29 [get_ports flashData[1]]
set_property PACKAGE_PIN V26 [get_ports flashData[2]]
set_property PACKAGE_PIN V27 [get_ports flashData[3]]
set_property PACKAGE_PIN W28 [get_ports flashData[4]]
set_property PACKAGE_PIN W29 [get_ports flashData[5]]
set_property PACKAGE_PIN W25 [get_ports flashData[6]]
set_property PACKAGE_PIN Y25 [get_ports flashData[7]]
set_property PACKAGE_PIN Y28 [get_ports flashData[8]]
set_property PACKAGE_PIN V31 [get_ports flashData[9]]
set_property PACKAGE_PIN V32 [get_ports flashData[10]]
set_property PACKAGE_PIN W33 [get_ports flashData[11]]
set_property PACKAGE_PIN W34 [get_ports flashData[12]]
set_property PACKAGE_PIN V34 [get_ports flashData[13]]
set_property PACKAGE_PIN Y32 [get_ports flashData[14]]
set_property PACKAGE_PIN Y33 [get_ports flashData[15]]
set_property IOSTANDARD LVCMOS25 [get_ports flashData[*]]
set_property PULLUP true [get_ports flashData[*]]

set_property PACKAGE_PIN M31  [get_ports flashAdv]
set_property IOSTANDARD LVCMOS25 [get_ports flashAdv]

set_property PACKAGE_PIN Y27  [get_ports flashCe]
set_property IOSTANDARD LVCMOS25 [get_ports flashCe]

set_property PACKAGE_PIN U34  [get_ports flashOe]
set_property IOSTANDARD LVCMOS25 [get_ports flashOe]

set_property PACKAGE_PIN T34  [get_ports flashWe]
set_property IOSTANDARD LVCMOS25 [get_ports flashWe]

set_property PACKAGE_PIN Y30  [get_ports sysClk]
set_property IOSTANDARD LVCMOS25 [get_ports sysClk]

# Grounding: "FLASH_A26"
set_property PACKAGE_PIN N31     [get_ports tieToGnd[0]]
set_property IOSTANDARD LVCMOS25 [get_ports tieToGnd[0]]

# Grounding: "EVR_TX_DIS"
set_property PACKAGE_PIN U7      [get_ports tieToGnd[1]]
set_property IOSTANDARD LVCMOS33 [get_ports tieToGnd[1]]

# Grounding: "QSFP_LP0"
set_property PACKAGE_PIN AP34    [get_ports tieToGnd[2]]
set_property IOSTANDARD LVCMOS33 [get_ports tieToGnd[2]]

# Grounding: "QSFP_LP1"
set_property PACKAGE_PIN AJ31    [get_ports tieToGnd[3]]
set_property IOSTANDARD LVCMOS33 [get_ports tieToGnd[3]]

# Grounding: "EVR_SEL0"
set_property PACKAGE_PIN V24     [get_ports tieToGnd[4]]
set_property IOSTANDARD LVCMOS25 [get_ports tieToGnd[4]]

# Grounding: "EVR_SEL1"
set_property PACKAGE_PIN T24     [get_ports tieToGnd[5]]
set_property IOSTANDARD LVCMOS25 [get_ports tieToGnd[5]]

# VDD-ing: "FLASH_RS0"
set_property PACKAGE_PIN P34     [get_ports tieToVdd[0]]
set_property IOSTANDARD LVCMOS25 [get_ports tieToVdd[0]]

###########################
# PGP: Pinout Constraints #
###########################

set_property PACKAGE_PIN AN19 [get_ports pgpTxP[0]]
set_property PACKAGE_PIN AP19 [get_ports pgpTxN[0]]
set_property PACKAGE_PIN AL18 [get_ports pgpRxP[0]]
set_property PACKAGE_PIN AM18 [get_ports pgpRxN[0]]

set_property PACKAGE_PIN AN21 [get_ports pgpTxP[1]]
set_property PACKAGE_PIN AP21 [get_ports pgpTxN[1]]
set_property PACKAGE_PIN AJ19 [get_ports pgpRxP[1]]
set_property PACKAGE_PIN AK19 [get_ports pgpRxN[1]]

set_property PACKAGE_PIN AL22 [get_ports pgpTxP[2]]
set_property PACKAGE_PIN AM22 [get_ports pgpTxN[2]]
set_property PACKAGE_PIN AL20 [get_ports pgpRxP[2]]
set_property PACKAGE_PIN AM20 [get_ports pgpRxN[2]]

set_property PACKAGE_PIN AN23 [get_ports pgpTxP[3]]
set_property PACKAGE_PIN AP23 [get_ports pgpTxN[3]]
set_property PACKAGE_PIN AJ21 [get_ports pgpRxP[3]]
set_property PACKAGE_PIN AK21 [get_ports pgpRxN[3]]

set_property PACKAGE_PIN AN17 [get_ports pgpTxP[4]]
set_property PACKAGE_PIN AP17 [get_ports pgpTxN[4]]
set_property PACKAGE_PIN AJ17 [get_ports pgpRxP[4]]
set_property PACKAGE_PIN AK17 [get_ports pgpRxN[4]]

set_property PACKAGE_PIN AN15 [get_ports pgpTxP[5]]
set_property PACKAGE_PIN AP15 [get_ports pgpTxN[5]]
set_property PACKAGE_PIN AL16 [get_ports pgpRxP[5]]
set_property PACKAGE_PIN AM16 [get_ports pgpRxN[5]]

set_property PACKAGE_PIN AL14 [get_ports pgpTxP[6]]
set_property PACKAGE_PIN AM14 [get_ports pgpTxN[6]]
set_property PACKAGE_PIN AJ15 [get_ports pgpRxP[6]]
set_property PACKAGE_PIN AK15 [get_ports pgpRxN[6]]

set_property PACKAGE_PIN AN13 [get_ports pgpTxP[7]]
set_property PACKAGE_PIN AP13 [get_ports pgpTxN[7]]
set_property PACKAGE_PIN AJ13 [get_ports pgpRxP[7]]
set_property PACKAGE_PIN AK13 [get_ports pgpRxN[7]]

set_property PACKAGE_PIN AG18  [get_ports pgpRefClkP]
set_property PACKAGE_PIN AH18  [get_ports pgpRefClkN]

##########################
# EVR Pinout Constraints #
##########################

set_property PACKAGE_PIN B13  [get_ports evrTxP]
set_property PACKAGE_PIN A13  [get_ports evrTxN]
set_property PACKAGE_PIN F13  [get_ports evrRxP]
set_property PACKAGE_PIN E13  [get_ports evrRxN]

set_property PACKAGE_PIN H16  [get_ports evrRefClkP]
set_property PACKAGE_PIN G16  [get_ports evrRefClkN]

###########################
# PCIe Pinout Constraints #
###########################

set_property PACKAGE_PIN B23 [get_ports pciTxP[3]]
set_property PACKAGE_PIN A23 [get_ports pciTxN[3]]
set_property PACKAGE_PIN F21 [get_ports pciRxP[3]]
set_property PACKAGE_PIN E21 [get_ports pciRxN[3]]

set_property PACKAGE_PIN D22 [get_ports pciTxP[2]]
set_property PACKAGE_PIN C22 [get_ports pciTxN[2]]
set_property PACKAGE_PIN D20 [get_ports pciRxP[2]]
set_property PACKAGE_PIN C20 [get_ports pciRxN[2]]

set_property PACKAGE_PIN B21 [get_ports pciTxP[1]]
set_property PACKAGE_PIN A21 [get_ports pciTxN[1]]
set_property PACKAGE_PIN F19 [get_ports pciRxP[1]]
set_property PACKAGE_PIN E19 [get_ports pciRxN[1]]

set_property PACKAGE_PIN B19 [get_ports pciTxP[0]]
set_property PACKAGE_PIN A19 [get_ports pciTxN[0]]
set_property PACKAGE_PIN D18 [get_ports pciRxP[0]]
set_property PACKAGE_PIN C18 [get_ports pciRxN[0]]

set_property PACKAGE_PIN H18  [get_ports pciRefClkP]
set_property PACKAGE_PIN G18  [get_ports pciRefClkN]

set_property PACKAGE_PIN L23  [get_ports pciRstL]
set_property IOSTANDARD LVCMOS33 [get_ports pciRstL]
set_property PULLUP true [get_ports pciRstL]
set_false_path -from [get_ports pciRstL]
