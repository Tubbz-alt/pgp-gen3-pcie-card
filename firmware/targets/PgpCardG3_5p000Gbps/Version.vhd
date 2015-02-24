-------------------------------------------------------------------------------
-- Title         : Version File
-- Project       : PGP To PCI-E Bridge Card, 8x
-------------------------------------------------------------------------------
-- File          : PgpCard8xG2Version.vhd
-- Author        : Ryan Herbst, rherbst@slac.stanford.edu
-- Created       : 04/27/2010
-------------------------------------------------------------------------------
-- Description:
-- Version Constant Module.
-------------------------------------------------------------------------------
-- Copyright (c) 2010 by SLAC National Accelerator Laboratory. All rights reserved.
-------------------------------------------------------------------------------
-- Modification history:
-- 04/27/2010: created.
-------------------------------------------------------------------------------
LIBRARY ieee;
USE ieee.std_logic_1164.ALL;

package Version is

constant FPGA_VERSION_C : std_logic_vector(31 downto 0) := x"CEC83002"; -- MAKE_VERSION

constant BUILD_STAMP_C : string := "PgpCardG3_5p000Gbps: Vivado v2014.1 (x86_64) Built Thu Feb 19 14:12:56 PST 2015 by ruckman";

end Version;

-------------------------------------------------------------------------------
-- Revision History:
--
-- 01/06/2015 (0xCEC83000): Initial Build
--
-- 01/30/2015 (0xCEC83001): Fixed the MGT RX reset forcing the whole QUAD to reset
--
-- 02/19/2015 (0xCEC83002): Fixed a bug in the EVR mask triggering 
--
-------------------------------------------------------------------------------

